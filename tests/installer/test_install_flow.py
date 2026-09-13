import json
import os
import shutil
import subprocess
from pathlib import Path

from conftest import REPO


def prepare_installer(sandbox):
    shutil.copy(REPO / 'install.sh', sandbox.dotfiles_dir / 'install.sh')
    sandbox.stub('sudo', '[ "$1" = "-v" ] && exit 0\n[ "$1" = "-n" ] && exit 0\nexec "$@"')
    sandbox.stub('pacman', 'echo base')
    sandbox.stub('gum', 'printf "%s\\n" "$*"')
    for name in ('stow', 'lspci', 'curl', 'git'):
        sandbox.stub(name, '')
    (sandbox.dotfiles_dir / 'lib/package.sh').write_text('hardware_packages_setup() { :; }\npackages_custom() { :; }\n')
    (sandbox.dotfiles_dir / 'lib/hardware-packages.sh').write_text('hardware_packages_setup() { :; }\n')
    (sandbox.dotfiles_dir / 'lib/package/preflight.sh').write_text('run_preflight_checks() { :; }\n')
    (sandbox.dotfiles_dir / 'lib/package/verify.sh').write_text('run_full_verification() { test ! -f "$HOME/fail-verification"; }\n')
    (sandbox.dotfiles_dir / 'install/packages/base.sh').write_text('''echo "$1" >> "$HOME/phases"
if [[ "$1" == aur && -f "$HOME/fail-aur" ]]; then
    exit 7
fi
''')
    (sandbox.dotfiles_dir / 'install/config/all.sh').write_text('echo config >> "$HOME/phases"\n')
    (sandbox.dotfiles_dir / 'install/post/all.sh').write_text('echo success-screen\n')


def run_installer(sandbox, *args):
    env = dict(os.environ, HOME=str(sandbox.root), PATH=f'{sandbox.bin_dir}:/usr/bin:/bin', TERM='dumb')
    for name in list(env):
        if name.startswith('DOTFILES_'):
            del env[name]
    return subprocess.run(['bash', str(sandbox.dotfiles_dir / 'install.sh'), *args], env=env, capture_output=True, text=True, timeout=15)


def test_failure_stops_and_retry_resumes_after_official_packages(sandbox):
    prepare_installer(sandbox)
    failure = sandbox.root / 'fail-aur'
    failure.touch()
    result = run_installer(sandbox)
    assert result.returncode == 1, result.stdout + result.stderr
    state = json.loads((sandbox.root / '.dotfiles-install-state.json').read_text())
    assert state['status'] == 'failed'
    assert state['resume_point'] == 'packages_aur'
    assert 'packages_official' in state['completed_phases']
    assert 'success-screen' not in result.stdout
    assert '--resume' in result.stdout
    failure.unlink()
    result = run_installer(sandbox)
    assert result.returncode == 0, result.stdout + result.stderr
    assert (sandbox.root / 'phases').read_text().splitlines() == ['official', 'aur', 'aur', 'config']
    state = json.loads((sandbox.root / '.dotfiles-install-state.json').read_text())
    assert state['status'] == 'completed'
    assert state['resume_point'] is None
    assert 'success-screen' in result.stdout


def test_failed_verification_never_reports_complete(sandbox):
    prepare_installer(sandbox)
    (sandbox.root / 'fail-verification').touch()
    result = run_installer(sandbox)
    assert result.returncode == 1
    state = json.loads((sandbox.root / '.dotfiles-install-state.json').read_text())
    assert state['status'] == 'failed'
    assert state['resume_point'] == 'verification'
    assert 'success-screen' not in result.stdout


def test_state_and_invalid_flags_never_invoke_sudo(sandbox):
    prepare_installer(sandbox)
    result = run_installer(sandbox, '--state')
    assert result.returncode == 0, result.stdout + result.stderr
    result = run_installer(sandbox, '--typo')
    assert result.returncode == 2
    assert not any(call.startswith('sudo ') or call.startswith('pacman ') for call in sandbox.calls())
