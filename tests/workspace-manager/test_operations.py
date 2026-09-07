import importlib.util
import json
import multiprocessing
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch

BACKEND = Path(__file__).resolve().parents[2] / 'stow/quickshell/.config/quickshell/assets/scripts/workspace-manager.py'
spec = importlib.util.spec_from_file_location('manager_operations', BACKEND)
manager = importlib.util.module_from_spec(spec)
spec.loader.exec_module(manager)


class OperationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.repo = self.directory / 'repo'
        self.state = self.directory / 'state'
        self.state.mkdir()
        (self.repo / 'install/helpers').mkdir(parents=True)
        (self.repo / 'lib').mkdir()
        (self.repo / 'install/helpers/all.sh').write_text('')
        functions = ['show_hardware_info', 'run_full_verification', 'packages_manage', 'packages_install', 'packages_clean_unlisted',
                     'packages_status', 'config_manage_interactive', 'config_link_all', 'config_unlink_all', 'config_status',
                     'hardware_packages_setup', 'hardware_packages_status', 'system_apply', 'system_status', 'theme_install_gtk',
                     'theme_uninstall_gtk', 'theme_status', 'shell_setup', 'shell_status', 'hyprland_setup_all', 'hyprland_status']
        self.package_source = '\n'.join(name + '() { printf "called ' + name + '\\n"; }' for name in functions) + '\n'
        (self.repo / 'lib/package.sh').write_text(self.package_source)
        for module in ['config', 'shell', 'theme', 'hyprland', 'system', 'menu']:
            (self.repo / f'lib/{module}.sh').write_text('')
        (self.repo / 'lib/install-state.sh').write_text('declare -a INSTALL_PHASES=(preflight hardware packages)\nshow_state() { printf "%s\\n" "${INSTALL_PHASES[@]}"; }\n')
        (self.repo / 'install.sh').write_text('printf "%s\\n" "$@" > "$DOTFILES_DIR/arguments"\n')
        for name, value in [('REPO', self.repo), ('STATE', self.state)]:
            mocked = patch.object(manager, name, value)
            mocked.start()
            self.addCleanup(mocked.stop)
        refresh = patch.object(manager, 'overview', return_value={})
        refresh.start()
        self.addCleanup(refresh.stop)

    def launch(self, operation, **options):
        request = {'id': 'test-job', 'action': 'operation', 'operation': operation, **options}
        process = multiprocessing.get_context('fork').Process(target=manager.worker, args=(request,))
        process.start()
        self.addCleanup(self.stop, process)
        return process

    @staticmethod
    def stop(process):
        if process.is_alive():
            process.kill()
        process.join(5)

    def completed(self, process):
        process.join(10)
        self.assertFalse(process.is_alive(), 'Operation does not terminate')
        return manager.read_json('job.json', {})

    def question(self, previous=''):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            question = manager.read_json('prompt.json', {})
            if question.get('id') and question['id'] != previous:
                return question
            time.sleep(0.03)
        self.fail('No native question appears')

    def answer(self, question, **values):
        return manager.respond({'id': question['id'], 'jobId': question['jobId'], **values})

    def set_operation(self, source):
        (self.repo / 'lib/package.sh').write_text(self.package_source + '\npackages_manage() {\n' + source + '\n}\n')

    def test_every_catalog_action_dispatches(self):
        for operation in manager.OPERATIONS:
            with self.subTest(operation=operation):
                job = self.completed(self.launch(operation))
                self.assertEqual(job['status'], 'completed', (operation, (self.state / 'activity.log').read_text()))

    def test_original_menu_sections_are_all_represented(self):
        self.assertTrue({'overview', 'packages', 'cleanup', 'configs', 'hardware', 'system', 'themes', 'shell', 'hyprland', 'installation'}.issubset({page['id'] for page in manager.CATALOG}))

    def test_full_install_options_and_resume(self):
        self.assertEqual(self.completed(self.launch('full_install', skipPackages=True, skipConfigs=True, fresh=True))['status'], 'completed')
        self.assertEqual((self.repo / 'arguments').read_text().splitlines(), ['--skip-packages', '--skip-configs', '--fresh'])
        self.assertEqual(self.completed(self.launch('resume_install'))['status'], 'completed')
        self.assertEqual((self.repo / 'arguments').read_text().splitlines(), ['--resume'])
        with self.assertRaises(ValueError):
            manager.validate({'action': 'operation', 'operation': 'resume_install', 'fresh': True})

    def test_multiselect_then_confirmation_preserves_values(self):
        self.set_operation('result=$(gum choose --no-limit --selected="hypr (linked)" --header "Choose configurations" "hypr (linked)" "quickshell (linked)" "kitty")\nprintf "%s" "$result" > "$DOTFILES_DIR/chosen"\nif gum confirm "Apply selections?"; then touch "$DOTFILES_DIR/applied"; fi\nreturn 0')
        process = self.launch('packages_manage')
        question = self.question()
        self.assertEqual(question['selected'], ['hypr (linked)'])
        self.assertTrue(question['multiple'])
        self.answer(question, values=['hypr (linked)', 'kitty'])
        confirmation = self.question(question['id'])
        self.assertEqual(confirmation['title'], 'Apply selections?')
        self.answer(confirmation, accepted=True)
        self.assertEqual(self.completed(process)['status'], 'completed')
        self.assertEqual((self.repo / 'chosen').read_text(), 'hypr (linked)\nkitty')
        self.assertTrue((self.repo / 'applied').exists())

    def test_cancel_cannot_turn_into_remove_everything(self):
        self.set_operation('trap ":" TERM\nresult=$(printf "one\\ntwo\\n" | gum filter --no-limit --placeholder "Keep packages")\ntouch "$DOTFILES_DIR/must-not-run"')
        process = self.launch('packages_manage')
        self.answer(self.question(), cancel=True)
        self.assertEqual(self.completed(process)['status'], 'cancelled')
        self.assertFalse((self.repo / 'must-not-run').exists())

    def test_skip_confirmation_is_not_cancellation(self):
        self.set_operation('if gum confirm "Optional step?"; then touch "$DOTFILES_DIR/skipped"; fi\nreturn 0')
        process = self.launch('packages_manage')
        self.answer(self.question(), accepted=False)
        self.assertEqual(self.completed(process)['status'], 'completed')
        self.assertFalse((self.repo / 'skipped').exists())

    def test_input_prompt_and_stale_response_validation(self):
        self.set_operation('result=$(gum input --prompt "Package label" --value "initial")\nprintf "%s" "$result" > "$DOTFILES_DIR/input"')
        process = self.launch('packages_manage')
        question = self.question()
        self.assertEqual(question['title'], 'Package label')
        self.assertEqual(question['value'], 'initial')
        with self.assertRaises(ValueError):
            manager.respond({'id': 'stale', 'jobId': 'test-job', 'values': ['ignored']})
        self.answer(question, values=['a value with spaces'])
        self.assertEqual(self.completed(process)['status'], 'completed')
        self.assertEqual((self.repo / 'input').read_text(), 'a value with spaces')

    def test_reported_errors_cannot_become_success(self):
        self.set_operation('log_error "failed inner operation"\nreturn 0')
        self.assertEqual(self.completed(self.launch('packages_manage'))['status'], 'failed')

    def test_read_only_operation_cannot_escalate(self):
        path = self.repo / 'lib/package.sh'
        path.write_text(self.package_source + '\nrun_full_verification() { sudo touch "$DOTFILES_DIR/forbidden"; }\n')
        self.assertEqual(self.completed(self.launch('verify'))['status'], 'failed')
        self.assertFalse((self.repo / 'forbidden').exists())


if __name__ == '__main__':
    unittest.main()
