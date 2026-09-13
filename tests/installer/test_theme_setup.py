import json
import shutil
import subprocess
import tomllib
from pathlib import Path

import pytest

from conftest import REPO, source


def test_all_matugen_templates_render_without_optional_apps(tmp_path):
    if not shutil.which('matugen'):
        pytest.skip('matugen required')
    config = tomllib.loads((REPO / 'stow/matugen/.config/matugen/config.toml').read_text())
    lines = ['[config]', 'reload_apps = false', 'set_wallpaper = false']
    for name, template in config['templates'].items():
        source_path = REPO / 'stow/matugen' / template['input_path'].removeprefix('~/')
        assert source_path.is_file(), f'Missing template: {source_path}'
        lines.extend([
            f'[templates.{name}]',
            f'input_path = {json.dumps(str(source_path))}',
            f'output_path = {json.dumps(str(tmp_path / name))}',
        ])
    config_path = tmp_path / 'config.toml'
    config_path.write_text('\n'.join(lines) + '\n')
    result = subprocess.run(['matugen', '-c', str(config_path), 'color', 'hex', '#4285f4'], capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, result.stdout + result.stderr
    for name in config['templates']:
        assert (tmp_path / name).stat().st_size > 0


def test_unattended_gtk_install_uses_defaults_without_prompting(sandbox):
    theme = sandbox.dotfiles_dir / 'themes/MacTahoe-gtk-theme'
    theme.mkdir(parents=True)
    (theme / '.git').mkdir()
    installer = theme / 'install.sh'
    installer.write_text('#!/bin/bash\nprintf "theme-installed\\n"\n')
    installer.chmod(0o755)
    sandbox.stub('git', '')
    sandbox.stub('gum', 'case "$1" in choose|confirm) exit 99 ;; esac')
    result = sandbox.run(f"""
export AUTO_YES=true
{source('lib/gtk.sh')}
apply_cursor_theme() {{ :; }}
gsettings() {{ :; }}
main install
""")
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'theme-installed' in result.stdout
    assert not any(call.startswith('gum choose') for call in sandbox.calls())
