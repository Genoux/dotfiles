import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "install/system/pacman-ignore.sh"
VENDOR_CONF = "[options]\nArchitecture = auto\nIgnorePkg = linux\nHoldPkg = pacman glibc\n\n[core]\nServer = https://example.invalid/$repo/os/$arch\n"


def apply(sandbox, conf: Path) -> subprocess.CompletedProcess:
    return sandbox.run(f'PACMAN_CONF="{conf}" bash "{SCRIPT}"')


def ignored_packages(conf: Path) -> list[str]:
    result = subprocess.run(
        ["pacman-conf", "--config", str(conf), "IgnorePkg"],
        capture_output=True, text=True, check=True,
    )
    return result.stdout.split()


def test_ignores_hand_built_ghostty_and_keeps_existing_entries(sandbox, tmp_path):
    conf = tmp_path / "pacman.conf"
    conf.write_text(VENDOR_CONF)

    result = apply(sandbox, conf)

    assert result.returncode == 0, result.stdout + result.stderr
    assert sorted(ignored_packages(conf)) == ["ghostty-git", "ghostty-terminfo-git", "linux"]


def test_rerun_leaves_pacman_conf_unchanged(sandbox, tmp_path):
    conf = tmp_path / "pacman.conf"
    conf.write_text(VENDOR_CONF)
    apply(sandbox, conf)
    after_first_run = conf.read_text()

    result = apply(sandbox, conf)

    assert result.returncode == 0, result.stdout + result.stderr
    assert conf.read_text() == after_first_run
