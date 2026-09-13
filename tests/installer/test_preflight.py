from conftest import source


def _stub_pacman_si(sandbox, known_names):
    body = "\n".join(
        f'if [ "$name" = "{n}" ]; then printf "Name            : %s\\n" "$name"; fi'
        for n in known_names
    )
    sandbox.stub(
        "pacman",
        f"""
if [ "$1" = "-Si" ]; then
    shift
    [ "$1" = "--" ] && shift
    for name in "$@"; do
        {body}
    done
    exit 0
fi
if [ "$1" = "-Sg" ]; then
    exit 1
fi
""",
    )


def _stub_curl_aur(sandbox, known_names):
    results = ",".join(f'{{"Name":"{n}"}}' for n in known_names)
    sandbox.stub("curl", f'printf \'{{"results":[{results}]}}\'')


def test_accepts_names_that_resolve(sandbox):
    sandbox.write_package_file("arch.package", ["base", "git"])
    sandbox.write_package_file("aur.package", ["yay"])
    _stub_pacman_si(sandbox, ["base", "git"])
    _stub_curl_aur(sandbox, ["yay"])

    result = sandbox.run(
        f"""
{source("lib/package/install-official.sh", "lib/package/install-aur.sh", "lib/package/preflight.sh")}
check_package_names
echo "exit=$?"
"""
    )
    assert "exit=0" in result.stdout, result.stdout + result.stderr


def test_rejects_unknown_official_and_aur_names(sandbox):
    sandbox.write_package_file("arch.package", ["base", "not-a-real-package"])
    sandbox.write_package_file("aur.package", ["yay", "not-a-real-aur-package"])
    _stub_pacman_si(sandbox, ["base"])
    _stub_curl_aur(sandbox, ["yay"])

    result = sandbox.run(
        f"""
{source("lib/package/install-official.sh", "lib/package/install-aur.sh", "lib/package/preflight.sh")}
check_package_names
echo "exit=$?"
"""
    )
    assert "exit=1" in result.stdout
    assert "not-a-real-package" in result.stdout
    assert "not-a-real-aur-package" in result.stdout


def test_preflight_runs_before_any_package_phase_in_install_sh():
    text = (__import__("pathlib").Path(__file__).resolve().parents[2] / "install.sh").read_text()
    preflight_pos = text.index('start_phase "preflight"')
    packages_pos = text.index('start_phase "packages_official"')
    assert preflight_pos < packages_pos


def test_names_only_resolve_after_the_db_has_been_synced(sandbox):
    # pacman -Si reports every name as unknown until -Sy has run — exactly
    # what a never-synced or stale DB looks like on a fresh install. If
    # sync_pacman_db doesn't run (or runs after check_package_names), this
    # would reject every name in a perfectly valid, freshly-written
    # packages/arch.package.
    synced_marker = sandbox.root / "synced"
    sandbox.write_package_file("arch.package", ["base"])
    sandbox.write_package_file("aur.package", [])
    sandbox.stub(
        "pacman",
        f"""
if [ "$1" = "-Sy" ]; then
    touch "{synced_marker}"
    exit 0
fi
if [ "$1" = "-Si" ]; then
    if [ ! -f "{synced_marker}" ]; then
        exit 1
    fi
    shift
    [ "$1" = "--" ] && shift
    for name in "$@"; do
        if [ "$name" = "base" ]; then printf "Name            : %s\\n" "$name"; fi
    done
    exit 0
fi
if [ "$1" = "-Sg" ]; then
    exit 1
fi
""",
    )
    _stub_curl_aur(sandbox, [])

    result = sandbox.run(
        f"""
{source("lib/package/install-official.sh", "lib/package/install-aur.sh", "lib/package/preflight.sh")}
sync_pacman_db
check_package_names
echo "exit=$?"
"""
    )
    assert "exit=0" in result.stdout, result.stdout + result.stderr

    calls = sandbox.calls()
    sy_index = next(i for i, c in enumerate(calls) if c.startswith("pacman -Sy"))
    si_index = next(i for i, c in enumerate(calls) if c.startswith("pacman -Si"))
    assert sy_index < si_index, calls


def test_sync_failure_is_reported(sandbox):
    sandbox.stub("pacman", "", exit_code=1)
    result = sandbox.run(
        f"""
{source("lib/package/preflight.sh")}
sync_pacman_db
echo "exit=$?"
"""
    )
    assert "exit=1" in result.stdout


def test_packages_prepare_no_longer_duplicates_the_sync(sandbox):
    # sync_pacman_db (preflight) is now the only `-Sy` in the install path;
    # a second one in packages_prepare only widened the sync-to-upgrade gap.
    content = (sandbox.dotfiles_dir / "lib/package/core.sh").read_text()
    code_lines = [l for l in content.splitlines() if not l.strip().startswith("#")]
    assert not any("pacman -Sy" in l for l in code_lines)
