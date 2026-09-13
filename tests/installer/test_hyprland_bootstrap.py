from conftest import REPO


def test_first_login_configs_are_generated_without_a_running_compositor(sandbox):
    sandbox.stub('lspci', "echo 'VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI]'")
    sandbox.stub('lsmod', '')
    sandbox.stub('hyprctl', 'exit 1')
    sandbox.stub('hyprpm', '')
    (sandbox.dotfiles_dir / 'lib/hyprland-plugins.sh').write_text('setup_hyprland_plugins() { :; }\n')
    result = sandbox.run(f"""
export DOTFILES_INSTALL="$DOTFILES_DIR/install"
bash -e "$DOTFILES_INSTALL/config/hyprland.sh"
""")
    assert result.returncode == 0, result.stdout + result.stderr
    gpu = (sandbox.root / '.config/hypr/gpu.lua').read_text()
    monitors = (sandbox.root / '.config/hypr/monitors.lua').read_text()
    assert 'radeonsi' in gpu
    assert 'nvidia' not in gpu.lower()
    assert 'mode = "preferred"' in monitors
    assert not any(call.startswith('hyprctl reload') for call in sandbox.calls())
    assert (sandbox.root / '.local/state/dotfiles/hyprland-setup-pending').exists()
    assert not any(call.startswith('hyprpm ') for call in sandbox.calls())


def test_regular_login_only_reloads_plugins(sandbox):
    sandbox.stub('hyprpm', '')
    result = sandbox.run(f'bash "{REPO}/stow/scripts/.local/bin/system-hyprland-plugins"')
    assert result.returncode == 0, result.stderr
    assert sandbox.calls() == ['hyprpm reload -n']
