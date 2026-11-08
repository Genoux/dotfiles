import json
import re
import shutil
import subprocess
import tomllib

import pytest

from conftest import REPO, source

requires_matugen = pytest.mark.skipif(not shutil.which('matugen'), reason='matugen required')


def render_matugen_templates(output_dir):
    templates = tomllib.loads((REPO / 'stow/matugen/.config/matugen/config.toml').read_text())['templates']
    lines = ['[config]', 'reload_apps = false', 'set_wallpaper = false']
    for name, template in templates.items():
        source_path = REPO / 'stow/matugen' / template['input_path'].removeprefix('~/')
        assert source_path.is_file(), f'Missing template: {source_path}'
        lines.extend([
            f'[templates.{name}]',
            f'input_path = {json.dumps(str(source_path))}',
            f'output_path = {json.dumps(str(output_dir / name))}',
        ])
    config_path = output_dir / 'config.toml'
    config_path.write_text('\n'.join(lines) + '\n')
    result = subprocess.run(['matugen', '-c', str(config_path), 'color', 'hex', '#4285f4'], capture_output=True, text=True, timeout=20)
    assert result.returncode == 0, result.stdout + result.stderr
    return templates


def relative_luminance(hex_color):
    channels = [int(hex_color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    red, green, blue = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def contrast_ratio(foreground, background):
    lighter, darker = sorted([relative_luminance(foreground), relative_luminance(background)], reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


@requires_matugen
def test_all_matugen_templates_render_without_optional_apps(tmp_path):
    for name in render_matugen_templates(tmp_path):
        assert (tmp_path / name).stat().st_size > 0


@requires_matugen
def test_every_ghostty_palette_slot_is_legible_on_the_background(tmp_path):
    render_matugen_templates(tmp_path)
    theme = (tmp_path / 'ghostty').read_text()
    background = re.search(r'^background = (#\w{6})$', theme, re.M).group(1)
    palette = dict(re.findall(r'^palette = (\d+)=(#\w{6})$', theme, re.M))
    assert len(palette) == 16
    illegible = {slot: color for slot, color in palette.items() if contrast_ratio(color, background) < 3}
    assert not illegible, f'ANSI slots below 3:1 on {background}: {illegible}'


def run_unattended_gtk_install(sandbox, installer_body):
    theme = sandbox.dotfiles_dir / 'themes/MacTahoe-gtk-theme'
    theme.mkdir(parents=True)
    (theme / '.git').mkdir()
    installer = theme / 'install.sh'
    installer.write_text(f'#!/bin/bash\n{installer_body}\n')
    installer.chmod(0o755)
    sandbox.stub('git', '')
    return sandbox.run(f"""
export AUTO_YES=true
{source('lib/gtk.sh')}
apply_cursor_theme() {{ :; }}
gsettings() {{ :; }}
main install
""")


def test_unattended_gtk_install_uses_defaults_without_prompting(sandbox):
    sandbox.stub('gum', 'case "$1" in choose|confirm) exit 99 ;; esac')
    result = run_unattended_gtk_install(sandbox, 'printf "theme-installed\\n"')
    assert result.returncode == 0, result.stdout + result.stderr
    assert 'theme-installed' in result.stdout
    assert not any(call.startswith('gum choose') for call in sandbox.calls())


def test_gtk_install_layers_matugen_colors_and_compositor_blur_over_the_theme(sandbox):
    result = run_unattended_gtk_install(sandbox, """
gtk4="$HOME/.config/gtk-4.0"
mkdir -p "$gtk4" && touch "$gtk4/gtk-Dark.css"
ln -sf "$gtk4/gtk-Dark.css" "$gtk4/gtk.css"
""")
    assert result.returncode == 0, result.stdout + result.stderr
    user_css = sandbox.root / '.config/gtk-4.0/gtk.css'
    assert not user_css.is_symlink()
    css = user_css.read_text()
    gtk4 = sandbox.root / '.config/gtk-4.0'
    theme_import = f'@import url("file://{gtk4}/gtk-Dark.css");'
    matugen_import = f'@import url("file://{gtk4}/matugen-colors.css");'
    assert css.index(theme_import) < css.index(matugen_import)
    assert 'backdrop-filter: blur(' in css
    assert 'background-color: alpha(@popover_fg_color, 0.1);' in css
