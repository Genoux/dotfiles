from conftest import source


def test_official_install_invokes_pacman_exactly_once_with_needed(sandbox):
    sandbox.stub("pacman", "")
    result = sandbox.run(
        f"""
{source("lib/package/install-official.sh")}
packages=(base git)
install_official_packages packages
"""
    )
    assert result.returncode == 0, result.stderr
    pacman_calls = [c for c in sandbox.calls() if c.startswith("pacman ")]
    assert len(pacman_calls) == 1, pacman_calls
    assert "--needed" in pacman_calls[0]
    assert "-Syu" in pacman_calls[0]
    assert "base" in pacman_calls[0] and "git" in pacman_calls[0]


def test_official_install_empty_list_does_not_call_pacman(sandbox):
    sandbox.stub("pacman", "")
    result = sandbox.run(
        f"""
{source("lib/package/install-official.sh")}
packages=()
install_official_packages packages
"""
    )
    assert result.returncode == 0, result.stderr
    assert sandbox.calls() == []


def test_official_install_failure_returns_nonzero(sandbox):
    sandbox.stub("pacman", "", exit_code=1)
    result = sandbox.run(
        f"""
{source("lib/package/install-official.sh")}
packages=(base)
install_official_packages packages
echo "exit=$?"
"""
    )
    assert "exit=1" in result.stdout
