from conftest import source


def test_skipped_not_failed_when_gh_unauthenticated(sandbox):
    sandbox.write_package_file("custom.package", ["Genoux/flow"])
    sandbox.stub("gh", "case \"$1 $2\" in\n  'auth status') exit 1 ;;\n  'auth login') exit 1 ;;\nesac")
    result = sandbox.run(
        f"""
{source("lib/package/custom.sh")}
packages_custom
echo "exit=$?"
"""
    )
    assert result.returncode == 0, result.stderr
    assert "exit=0" in result.stdout
    build_calls = [c for c in sandbox.calls() if c.startswith("gh repo clone")]
    assert build_calls == []


def test_skips_cleanly_when_nothing_declared(sandbox):
    sandbox.write_package_file("custom.package", [])
    result = sandbox.run(
        f"""
{source("lib/package/custom.sh")}
packages_custom
echo "exit=$?"
"""
    )
    assert result.returncode == 0, result.stderr
    assert "exit=0" in result.stdout
    assert sandbox.calls() == []


def test_builds_each_repo_when_authenticated(sandbox):
    sandbox.write_package_file("custom.package", ["Genoux/flow"])
    sandbox.stub("gh", "if [ \"$1 $2\" = 'auth status' ]; then exit 0; fi\nif [ \"$1\" = repo ]; then mkdir -p \"$4\"; touch \"$4/PKGBUILD\"; fi")
    sandbox.stub("makepkg", "")
    result = sandbox.run(
        f"""
{source("lib/package/custom.sh")}
packages_custom
echo "exit=$?"
"""
    )
    assert result.returncode == 0, result.stderr
    assert "exit=0" in result.stdout
    makepkg_calls = [c for c in sandbox.calls() if c.startswith("makepkg")]
    assert len(makepkg_calls) == 1
    assert "-si" in makepkg_calls[0] or "-s -i" in makepkg_calls[0]


def test_build_failure_fails_the_phase(sandbox):
    sandbox.write_package_file("custom.package", ["Genoux/flow"])
    sandbox.stub("gh", "if [ \"$1 $2\" = 'auth status' ]; then exit 0; fi\nif [ \"$1\" = repo ]; then mkdir -p \"$4\"; touch \"$4/PKGBUILD\"; fi")
    sandbox.stub("makepkg", "", exit_code=1)
    result = sandbox.run(
        f"""
{source("lib/package/custom.sh")}
packages_custom
echo "exit=$?"
"""
    )
    assert result.returncode == 0, result.stderr
    assert "exit=1" in result.stdout


def test_full_install_does_not_open_github_login(sandbox):
    sandbox.write_package_file("custom.package", ["Genoux/flow"])
    sandbox.stub("gh", "exit 1")
    result = sandbox.run(f"""
export FULL_INSTALL=true
{source("lib/package/custom.sh")}
packages_custom
""")
    assert result.returncode == 0
    assert "gh auth login" not in sandbox.calls()
    assert not any(call.startswith("gh repo clone") for call in sandbox.calls())
