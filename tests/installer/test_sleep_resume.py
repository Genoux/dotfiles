import shlex
import shutil
from pathlib import Path

import pytest


REPO = Path(__file__).resolve().parents[2]


@pytest.mark.parametrize('lock_state', ['listed', 'process', 'missing'])
def test_resume_preserves_lock_and_only_starts_if_missing(sandbox, lock_state):
    sandbox.stub('hyprctl', '')
    sandbox.stub('sleep', '')
    sandbox.stub('pkill', 'exit 99')
    sandbox.stub('killall', 'exit 99')
    sandbox.stub(
        'quickshell',
        'echo "$HOME/.config/quickshell/lock.qml"' if lock_state == 'listed' else '',
    )
    sandbox.stub('pgrep', '', exit_code=0 if lock_state == 'process' else 1)
    local_bin = sandbox.root / '.local/bin'
    local_bin.mkdir(parents=True)
    for command in ['system-lock', 'system-awww-wallpaper', 'system-bluetooth-reconnect']:
        sandbox.stub(command, f'touch "$HOME/{command}.called"', log=False)
        shutil.copy2(sandbox.bin_dir / command, local_bin / command)

    script = REPO / 'stow/scripts/.local/bin/system-lock-after-sleep'
    result = sandbox.run(f'source {shlex.quote(str(script))}; wait')

    assert result.returncode == 0, result.stderr
    calls = sandbox.calls()
    assert not any(call.startswith(('pkill', 'killall')) for call in calls)
    assert (sandbox.root / 'system-lock.called').exists() == (lock_state == 'missing')
    assert 'hyprctl dispatch hl.dsp.dpms("on")' in calls
    assert (sandbox.root / 'system-bluetooth-reconnect.called').exists()
