from conftest import source


def test_aur_replaces_conflicts_without_refreshing_or_touching_npmrc(sandbox):
    npmrc = sandbox.root / ".npmrc"
    target = sandbox.root / "real-npmrc"
    target.write_text("prefix=/custom/path\n")
    npmrc.symlink_to(target)
    sandbox.stub("yay", 'test "$NPM_CONFIG_USERCONFIG" = /dev/null || exit 2\ntest -z "${NPM_CONFIG_PREFIX:-}" || exit 3')
    result = sandbox.run(f"""
{source("lib/package/install-aur.sh")}
ensure_yay_installed() {{ :; }}
export NPM_CONFIG_PREFIX=/custom/path
packages=(cliamp-bin)
install_aur_packages packages
""")
    assert result.returncode == 0, result.stderr
    call = next(call for call in sandbox.calls() if call.startswith("yay "))
    assert "--useask" in call
    assert "--batchinstall=false" in call
    assert "--refresh" not in call
    assert npmrc.is_symlink()
    assert target.read_text() == "prefix=/custom/path\n"


def test_installed_yay_provider_is_not_replaced_during_its_own_run(sandbox):
    sandbox.stub('pacman', 'echo yay-bin')
    sandbox.stub('yay', '')
    result = sandbox.run(f"""
{source('lib/package/install-aur.sh')}
ensure_yay_installed() {{ :; }}
packages=(yay cliamp-bin)
install_aur_packages packages
""")
    assert result.returncode == 0, result.stderr
    call = next(call for call in sandbox.calls() if call.startswith('yay '))
    assert call.split()[-1] == 'cliamp-bin'
    assert call.split().count('yay') == 1
