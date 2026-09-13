from conftest import source

COMMENTED_PACMAN_CONF = """[options]
Architecture = auto

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist

#[multilib]
#Include = /etc/pacman.d/mirrorlist
"""

ENABLED_PACMAN_CONF = COMMENTED_PACMAN_CONF.replace("#[multilib]", "[multilib]").replace(
    "#Include = /etc/pacman.d/mirrorlist\n", "Include = /etc/pacman.d/mirrorlist\n", 1
)


def test_enables_multilib_when_commented_out(sandbox):
    conf = sandbox.root / "pacman.conf"
    conf.write_text(COMMENTED_PACMAN_CONF)

    result = sandbox.run(
        f"""
export PACMAN_CONF="{conf}"
{source("lib/package/preflight.sh")}
ensure_multilib_enabled
echo "exit=$?"
"""
    )
    assert "exit=0" in result.stdout, result.stdout + result.stderr
    text = conf.read_text()
    assert "\n[multilib]\n" in text
    assert "[multilib]\nInclude = /etc/pacman.d/mirrorlist" in text


def test_already_enabled_is_unchanged(sandbox):
    conf = sandbox.root / "pacman.conf"
    conf.write_text(ENABLED_PACMAN_CONF)
    before = conf.read_text()

    result = sandbox.run(
        f"""
export PACMAN_CONF="{conf}"
{source("lib/package/preflight.sh")}
ensure_multilib_enabled
echo "exit=$?"
"""
    )
    assert "exit=0" in result.stdout, result.stdout + result.stderr
    assert conf.read_text() == before


def test_multilib_enabled_before_the_first_sync(sandbox):
    conf = sandbox.root / "pacman.conf"
    conf.write_text(COMMENTED_PACMAN_CONF)
    sandbox.stub("pacman", "case \"$1\" in -Sy) exit 0 ;; *) exit 0 ;; esac")

    result = sandbox.run(
        f"""
export PACMAN_CONF="{conf}"
{source("lib/package/preflight.sh")}
ensure_multilib_enabled
sync_pacman_db
echo "exit=$?"
"""
    )
    assert "exit=0" in result.stdout, result.stdout + result.stderr
    assert "[multilib]" in conf.read_text().splitlines()

    calls = sandbox.calls()
    sy_calls = [c for c in calls if c.startswith("pacman -Sy")]
    assert len(sy_calls) == 1


def test_run_preflight_checks_calls_multilib_before_pacman_lock():
    from pathlib import Path

    text = (Path(__file__).resolve().parents[2] / "lib/package/preflight.sh").read_text()
    body = text[text.index("run_preflight_checks()") :]
    multilib_pos = body.index("ensure_multilib_enabled")
    lock_pos = body.index("check_pacman_lock")
    assert multilib_pos < lock_pos
