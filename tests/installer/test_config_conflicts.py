import shutil

import pytest

from conftest import source


def test_existing_config_is_backed_up_without_adopting_it(sandbox):
    if not shutil.which('stow'):
        pytest.skip('GNU Stow required')
    package = sandbox.dotfiles_dir / 'stow/example'
    package.mkdir(parents=True)
    (package / '.example').write_text('repo settings\n')
    existing = sandbox.root / '.example'
    existing.write_text('old settings\n')
    result = sandbox.run(f"""
{source('lib/config.sh')}
graceful_error() {{ echo "$*" >&2; return 1; }}
config_link example true
""")
    assert result.returncode == 0, result.stderr
    assert existing.is_symlink()
    assert existing.read_text() == 'repo settings\n'
    backups = list((sandbox.root / '.local/state/dotfiles/config-backups').rglob('.example'))
    assert len(backups) == 1
    assert backups[0].read_text() == 'old settings\n'
    result = sandbox.run(f"{source('lib/config.sh')}\nconfig_link example true")
    assert result.returncode == 0, result.stderr
    assert len(list((sandbox.root / '.local/state/dotfiles/config-backups').rglob('.example'))) == 1
