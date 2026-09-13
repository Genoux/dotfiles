import re
import subprocess
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]


def test_dropin_disables_debug_exactly_once():
    content = (REPO / "system/makepkg.conf.d/dotfiles.conf").read_text()
    match = re.search(r"OPTIONS=\(([^)]*)\)", content)
    assert match, "no OPTIONS array found in the drop-in"
    options = match.group(1)
    assert "!!debug" not in options
    assert options.count("debug") == 1
    assert "!debug" in options


def test_dropin_builds_on_every_core():
    dropin = REPO / "system/makepkg.conf.d/dotfiles.conf"
    result = subprocess.run(
        ["bash", "-c", f'source "{dropin}"; echo "$MAKEFLAGS"; nproc'],
        capture_output=True, text=True, check=True,
    )
    makeflags, cores = result.stdout.split()
    assert makeflags == f"-j{cores}"


def test_installer_never_edits_etc_makepkg_conf_directly():
    content = (REPO / "install/system/makepkg.sh").read_text()
    code_lines = [
        line for line in content.splitlines() if not line.strip().startswith("#")
    ]
    # Every mention of /etc/makepkg.conf in actual code must be the .d
    # drop-in directory, never the bare file the old sed-based version
    # corrupted (comments are allowed to mention it as prose/history).
    for line in code_lines:
        assert not re.search(r"/etc/makepkg\.conf(?!\.d)", line), line
        assert not re.search(r"\bsed\b", line), line
