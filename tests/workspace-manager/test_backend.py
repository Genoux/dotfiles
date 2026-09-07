import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

BACKEND = Path(__file__).resolve().parents[2] / 'stow/quickshell/.config/quickshell/assets/scripts/workspace-manager.py'
spec = importlib.util.spec_from_file_location('workspace_manager', BACKEND)
manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manager)


class BackendTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        self.repo = self.home / 'dotfiles'
        (self.repo / 'packages').mkdir(parents=True)
        (self.repo / 'packages/arch.package').write_text('base\n')
        (self.repo / 'packages/aur.package').write_text('')
        (self.repo / 'packages/sync-exclude').write_text('idleon-desktop\n')
        query = patch.object(manager, 'capture', return_value='Name : trial')
        query.start()
        self.addCleanup(query.stop)
        for name, value in [('HOME', self.home), ('REPO', self.repo), ('STATE', self.home / 'state')]:
            mocked = patch.object(manager, name, value)
            mocked.start()
            self.addCleanup(mocked.stop)

    def test_rejects_options_and_shell_input(self):
        for package in ['--needed', 'foo;touch /tmp/test', 'foo bar', '../foo', '$(id)']:
            with self.assertRaises(ValueError):
                manager.validate({'action': 'install', 'package': package, 'source': 'official'})

    def test_existing_and_managed_packages_cannot_be_temporary(self):
        with patch.object(manager, 'installed', return_value={'installed'}), patch.object(manager, 'privileged') as privileged:
            for package in ['installed', 'base']:
                with self.assertRaises(RuntimeError):
                    manager.temporary_install(package, 'official')
            privileged.assert_not_called()

    def test_excludes_before_install_and_tracks_result(self):
        def install(*args):
            self.assertIn('trial', (self.repo / 'packages/sync-exclude').read_text().splitlines())
            self.assertEqual(manager.read_json('temporary.json', [])[0]['status'], 'installing')
            self.assertEqual(args, ('pacman', '-Syu', '--needed', '--noconfirm', '--', 'trial'))
        with patch.object(manager, 'installed', side_effect=[set(), {'trial'}]), patch.object(manager, 'privileged', side_effect=install):
            manager.temporary_install('trial', 'official')
        self.assertEqual(manager.read_json('temporary.json', [])[0]['status'], 'installed')
        self.assertEqual((self.repo / 'packages/arch.package').read_text(), 'base\n')

    def test_failed_install_stays_recoverable(self):
        with patch.object(manager, 'installed', return_value=set()), patch.object(manager, 'privileged', side_effect=RuntimeError('cancelled')):
            with self.assertRaisesRegex(RuntimeError, 'cancelled'):
                manager.temporary_install('trial', 'official')
        self.assertEqual(manager.read_json('temporary.json', [])[0]['status'], 'not installed')
        with patch.object(manager, 'installed', return_value=set()), patch.object(manager, 'privileged') as privileged:
            manager.finish_temporary('trial', False)
            privileged.assert_not_called()
        self.assertEqual(manager.read_json('temporary.json', []), [])
        self.assertEqual((self.repo / 'packages/sync-exclude').read_text(), 'idleon-desktop\n')

    def test_keep_preserves_preexisting_exclusion_and_manifest(self):
        manager.exclude('trial', True)
        manager.write_json('temporary.json', [{'name': 'trial', 'source': 'aur', 'ownsExclusion': False}])
        with patch.object(manager, 'installed', return_value={'trial'}):
            manager.finish_temporary('trial', True)
        self.assertEqual((self.repo / 'packages/sync-exclude').read_text(), 'idleon-desktop\ntrial\n')
        self.assertEqual((self.repo / 'packages/arch.package').read_text(), 'base\n')

    def test_remove_failure_retains_tracking(self):
        records = [{'name': 'trial', 'source': 'official', 'ownsExclusion': True}]
        manager.write_json('temporary.json', records)
        manager.exclude('trial', True)
        with patch.object(manager, 'installed', return_value={'trial'}), patch.object(manager, 'privileged', side_effect=RuntimeError('required by another package')):
            with self.assertRaises(RuntimeError):
                manager.finish_temporary('trial', False)
        self.assertEqual(manager.read_json('temporary.json', []), records)
        self.assertIn('trial', (self.repo / 'packages/sync-exclude').read_text())

    def test_orphans_only_remove_reviewed_still_unused_packages(self):
        with patch.object(manager, 'capture', return_value='reviewed\nnew-orphan'), patch.object(manager, 'privileged') as privileged:
            manager.clean('orphans', ['reviewed', 'now-required'])
            privileged.assert_called_once_with('pacman', '-Rn', '--noconfirm', '--', 'reviewed')

    def test_cache_symlink_cannot_delete_target(self):
        target = self.home / 'important'
        target.mkdir()
        (target / 'keep').write_text('keep')
        link = self.home / 'cache'
        link.symlink_to(target)
        with self.assertRaises(RuntimeError):
            manager.clear_directory(link)
        self.assertTrue((target / 'keep').exists())

    def test_yay_flags_precede_target_separator(self):
        with patch.object(manager, 'run') as run:
            manager.yay('-Syu', '--needed', '--', 'trial')
        command = run.call_args.args[0]
        self.assertLess(command.index('--sudo'), command.index('--'))
        self.assertEqual(command[-1], 'trial')

    def test_update_check_reports_partial_failure(self):
        def query(command, *args):
            if command[0] == 'yay':
                raise RuntimeError('offline')
            return 'base 1 -> 2'
        with patch.object(manager, 'capture', side_effect=query):
            with self.assertRaisesRegex(RuntimeError, 'offline'):
                manager.check_updates()
        data = manager.read_json('updates.json', {})
        self.assertEqual(data['packages'][0]['name'], 'base')
        self.assertEqual(len(data['errors']), 1)

    def test_detached_worker_lock_and_failure_status(self):
        import os
        bindir = self.home / 'bin'
        bindir.mkdir()
        for name in ['checkupdates', 'yay']:
            script = bindir / name
            script.write_text('#!/bin/sh\nsleep 1\necho simulated-failure >&2\nexit 1\n')
            script.chmod(0o755)
        env = {**os.environ, 'PATH': str(bindir) + ':' + os.environ['PATH'], 'XDG_STATE_HOME': str(self.home / 'detached')}
        def call(*args):
            return subprocess.run([sys.executable, str(BACKEND), *args], env=env, text=True, capture_output=True, timeout=5)
        first = call('start', '{"action":"check"}')
        self.assertEqual(first.returncode, 0, first.stdout)
        second = call('start', '{"action":"check"}')
        self.assertNotEqual(second.returncode, 0)
        self.assertIn('already running', second.stdout)
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            status = json.loads(call('status').stdout)
            if status['job'].get('status') == 'failed':
                break
            time.sleep(0.05)
        self.assertEqual(status['job']['id'], json.loads(first.stdout)['id'])
        self.assertEqual(status['job']['status'], 'failed')
        self.assertIn('simulated-failure', status['log'])
        self.assertFalse(status['busy'])


if __name__ == '__main__':
    unittest.main()
