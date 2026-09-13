import os
import re
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]

# network.sh writes directly to real /etc paths (iwd, systemd-network), so —
# apart from the resolv.conf logic below, which is parameterized on env vars
# specifically for this — it cannot be safely exercised by actually running
# it in a test sandbox without a real root or a filesystem overlay. This is a
# static check of the script's own text instead: it directly encodes the
# "never disrupt the network mid-install" contract network.sh is required to
# hold.
NETWORK_SH = (REPO / "install/system/network.sh").read_text()
SYSTEM_DIR = REPO / "install/system"

# iwd/systemd-networkd/NetworkManager own live connectivity (WiFi
# association, DHCP) — restarting or --now-starting any of them mid-install
# can drop the network this same run still needs. systemd-resolved is
# different: starting or restarting it doesn't touch an established
# connection (verified: it only affects name resolution, not the socket),
# so it's deliberately exempt — see configure_resolv_conf's own verify-
# before-symlink guard for how *that* risk is handled instead.
DISRUPTIVE_SERVICES = ("iwd", "systemd-networkd", "NetworkManager")


def test_never_restarts_or_now_starts_the_managed_network_services():
    for path in SYSTEM_DIR.glob("*.sh"):
        for line in path.read_text().splitlines():
            stripped = line.strip()
            if stripped.startswith("#"):
                continue
            if "systemctl" not in stripped:
                continue
            for service in DISRUPTIVE_SERVICES:
                if service not in stripped:
                    continue
                assert "restart" not in stripped, f"{path.name}: disruptive restart: {stripped!r}"
                assert "--now" not in stripped, f"{path.name}: disruptive --now: {stripped!r}"


def test_removes_stale_wireless_network_file():
    assert "/etc/systemd/network/25-wireless.network" in NETWORK_SH
    assert re.search(r"rm\s+-f\s+/etc/systemd/network/25-wireless\.network", NETWORK_SH)


def test_never_creates_a_second_wireless_network_file():
    # The old dual-DHCP bug came from networkd also owning wlan* addressing.
    assert "Name=wlan" not in NETWORK_SH


def test_resolved_fallback_dns_dropin_exists():
    dropin = (REPO / "system/systemd/resolved.conf.d/dotfiles.conf").read_text()
    assert "FallbackDNS=" in dropin
    assert "1.1.1.1" in dropin


def test_resolved_config_no_longer_a_separate_file():
    # Folded into network.sh — one owner, no duplicate enable/start logic.
    assert not (SYSTEM_DIR / "systemd-resolved.sh").exists()
    for path in (REPO / "install/system/setup.sh", REPO / "lib/system.sh"):
        assert "systemd-resolved.sh" not in path.read_text()


def _extract_function(source_text: str, name: str) -> str:
    """Pull just one function's definition out of a top-level script, so it
    can be tested without executing the rest of that script's real,
    system-mutating side effects (network.sh disables NetworkManager,
    installs iwd config, etc. unconditionally at the top level)."""
    start = source_text.index(f"{name}() {{")
    depth = 0
    for i in range(start, len(source_text)):
        if source_text[i] == "{":
            depth += 1
        elif source_text[i] == "}":
            depth -= 1
            if depth == 0:
                return source_text[start : i + 1]
    raise AssertionError(f"unbalanced braces extracting {name}()")


CONFIGURE_RESOLV_CONF_FN = _extract_function(NETWORK_SH, "configure_resolv_conf")


def _run_configure_resolv_conf(sandbox, resolv_conf, stub_resolv, resolvectl_body, resolvectl_exit=0):
    sandbox.stub("resolvectl", resolvectl_body, exit_code=resolvectl_exit)
    return sandbox.run(
        f"""
{CONFIGURE_RESOLV_CONF_FN}
configure_resolv_conf "{resolv_conf}" "{stub_resolv}"
echo "exit=$?"
"""
    )


def test_symlink_created_when_resolution_verifies(sandbox):
    resolv_conf = sandbox.root / "resolv.conf"
    stub_resolv = sandbox.root / "stub-resolv.conf"
    result = _run_configure_resolv_conf(sandbox, resolv_conf, stub_resolv, "")
    assert "exit=0" in result.stdout, result.stdout + result.stderr
    assert resolv_conf.is_symlink()
    assert os.readlink(resolv_conf) == str(stub_resolv)


def test_resolv_conf_untouched_when_resolution_fails(sandbox):
    resolv_conf = sandbox.root / "resolv.conf"
    stub_resolv = sandbox.root / "stub-resolv.conf"
    result = _run_configure_resolv_conf(sandbox, resolv_conf, stub_resolv, "", resolvectl_exit=1)
    assert "exit=1" in result.stdout, result.stdout + result.stderr
    assert not resolv_conf.exists()


def test_already_correct_symlink_is_a_noop_without_querying(sandbox):
    stub_resolv = sandbox.root / "stub-resolv.conf"
    stub_resolv.write_text("")
    resolv_conf = sandbox.root / "resolv.conf"
    resolv_conf.symlink_to(stub_resolv)

    # resolvectl would fail if called — proves the already-correct branch
    # short-circuits before ever querying.
    result = _run_configure_resolv_conf(sandbox, resolv_conf, stub_resolv, "", resolvectl_exit=1)
    assert "exit=0" in result.stdout, result.stdout + result.stderr
    assert "resolvectl" not in sandbox.calls_log.read_text()
