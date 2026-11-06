import os
import signal
import time

import pytest

from conftest import source

CORRUPT_SOURCES = "==> ERROR: One or more files did not pass the validity check!"
CONFLICT = ":: Remove geocode-glib-common? [y/N]\\nerror: unresolvable package conflicts detected"


def update_script(
    sandbox, yay_body: str, flatpak_body: str = "", parent_setup: str = "", pacman_body: str = ""
) -> str:
    # Every mutating command is a stub; sudo records and runs only pacman,
    # which is itself a stub.
    sandbox.stub("sudo", '[ "$1" = "pacman" ] && exec "$@"', log=True)
    sandbox.stub("pacman", pacman_body)
    for name in ("paccache", "journalctl", "git", "makepkg"):
        sandbox.stub(name, "")
    sandbox.stub("yay", f'[ "$1" = "--version" ] && exit 0\n{yay_body}')
    sandbox.stub("flatpak", flatpak_body)
    return f"""
{parent_setup}
export DOTFILES_UPDATE_MIN_ROOT_FREE_KIB=0
ensure_directory() {{ mkdir -p "$1"; }}
{source("install/helpers/logging.sh", "lib/package/core.sh", "lib/package/update.sh")}
start_log_monitor() {{ :; }}
stop_log_monitor() {{ :; }}
packages_update
echo "exit=$?"
echo "parent-userconfig=${{NPM_CONFIG_USERCONFIG-unset}}"
"""


def run_update(sandbox, yay_body: str, flatpak_body: str = "", parent_setup: str = "", pacman_body: str = ""):
    return sandbox.run(update_script(sandbox, yay_body, flatpak_body, parent_setup, pacman_body))


def exit_code_from(stdout: str) -> int:
    # -999: the script died before reporting, i.e. cleanup and exit never ran.
    reported = [line for line in stdout.splitlines() if line.startswith("exit=")]
    return int(reported[0].split("=")[1]) if reported else -999


def exit_code(result) -> int:
    return exit_code_from(result.stdout)


def calls_to(sandbox, command: str):
    return [call for call in sandbox.calls() if call.split()[0] == command]


def yay_updates(sandbox):
    return [call for call in calls_to(sandbox, "yay") if "-Sua" in call]


def test_success_updates_system_then_flatpak(sandbox):
    result = run_update(sandbox, "exit 0")

    assert exit_code(result) == 0, result.stderr
    assert len(yay_updates(sandbox)) == 1
    assert len(calls_to(sandbox, "flatpak")) == 1


# yay's log line, verbatim: no space between the name and "-exit".
def broken_package(name: str, status: int = 4) -> str:
    return f'echo " -> error making: {name}-exit status {status}"; exit 1'


def last_stderr_line(result) -> str:
    return result.stderr.rstrip().splitlines()[-1]


def test_conflict_stays_visible_fails_and_removes_nothing(sandbox):
    result = run_update(sandbox, "exit 0", pacman_body=f'printf "{CONFLICT}\\n"; exit 1')

    assert exit_code(result) == 1
    assert "Remove geocode-glib-common?" in result.stdout
    assert not any("-Rdd" in call for call in sandbox.calls())
    assert yay_updates(sandbox) == []
    assert calls_to(sandbox, "flatpak") == []


def test_official_update_runs_noconfirm_before_the_aur_one(sandbox):
    run_update(sandbox, "exit 0")

    updates = [call.split()[0] for call in sandbox.calls() if "-Syu" in call or "-Sua" in call]
    updates = [command for command in updates if command != "sudo"]
    assert updates == ["pacman", "yay"]
    assert calls_to(sandbox, "pacman") == ["pacman -Syu --noconfirm"]


def test_official_failure_is_a_hard_failure_and_skips_aur_and_flatpak(sandbox):
    result = run_update(sandbox, "exit 0", pacman_body='echo "error: failed to commit transaction"; exit 1')

    assert exit_code(result) == 1
    assert yay_updates(sandbox) == []
    assert calls_to(sandbox, "flatpak") == []


def test_broken_aur_package_is_skipped_not_retried_and_named_last(sandbox):
    result = run_update(sandbox, broken_package("brokenpkg"))

    assert exit_code(result) == 0, result.stderr
    assert len(yay_updates(sandbox)) == 1
    assert len(calls_to(sandbox, "flatpak")) == 1
    assert "AUR packages not updated: brokenpkg - they" in last_stderr_line(result)


def test_every_failed_aur_package_is_named_once(sandbox):
    result = run_update(
        sandbox,
        "\n".join(
            [
                'echo " -> error making: first - exit status 4"',
                'echo "error downloading sources: $HOME/.cache/yay/second"',
                'echo " -> error making: first - exit status 4"',
                "exit 1",
            ]
        ),
    )

    assert exit_code(result) == 0, result.stderr
    assert "AUR packages not updated: first second - they" in last_stderr_line(result)


def test_aur_failure_without_a_parsable_name_still_warns(sandbox):
    result = run_update(sandbox, 'echo "error: something broke"; exit 1')

    assert exit_code(result) == 0, result.stderr
    assert len(calls_to(sandbox, "flatpak")) == 1
    assert "not updated" in last_stderr_line(result)


def test_clean_update_prints_no_aur_warning(sandbox):
    result = run_update(sandbox, "exit 0")

    assert "not updated" not in result.stderr


def test_corrupt_sources_are_retried_once_after_purging_the_cache(sandbox):
    stale_archive = sandbox.root / ".cache/yay/pkg/pkg-1.tar.gz"
    stale_archive.parent.mkdir(parents=True)
    stale_archive.write_text("corrupt")
    counter = sandbox.root / "yay-runs"
    first_fails_second_succeeds = f"""
echo run >> "{counter}"
if [ "$(wc -l < "{counter}")" -eq 1 ]; then echo "{CORRUPT_SOURCES}"; exit 1; fi
"""
    result = run_update(sandbox, first_fails_second_succeeds)

    assert exit_code(result) == 0, result.stderr
    assert len(yay_updates(sandbox)) == 2
    assert not stale_archive.exists()
    assert len(calls_to(sandbox, "flatpak")) == 1


def test_package_fixed_by_the_clean_retry_is_not_named(sandbox):
    counter = sandbox.root / "yay-runs"
    first_fails_second_succeeds = f"""
echo run >> "{counter}"
if [ "$(wc -l < "{counter}")" -eq 1 ]; then
    echo "error downloading sources: $HOME/.cache/yay/apple-fonts"
    echo "{CORRUPT_SOURCES}"
    exit 1
fi
"""
    result = run_update(sandbox, first_fails_second_succeeds)

    assert exit_code(result) == 0, result.stderr
    assert len(yay_updates(sandbox)) == 2
    assert "apple-fonts" not in result.stderr
    assert "not updated" not in result.stderr


def test_failed_retry_keeps_the_original_error_skips_the_package_and_runs_flatpak(sandbox):
    result = run_update(
        sandbox,
        f'echo "error downloading sources: $HOME/.cache/yay/apple-fonts"; echo "{CORRUPT_SOURCES}"; exit 1',
    )

    assert exit_code(result) == 0, result.stderr
    assert len(yay_updates(sandbox)) == 2
    assert result.stdout.count(CORRUPT_SOURCES) >= 2
    assert len(calls_to(sandbox, "flatpak")) == 1
    assert "AUR packages not updated: apple-fonts - they" in last_stderr_line(result)


def test_failure_report_ends_with_the_latest_error_whatever_its_case(sandbox):
    older_errors = "".join(f"error: older failure {n}\\n" for n in range(8))
    result = run_update(
        sandbox,
        "exit 0",
        pacman_body=f'printf "{older_errors}"; echo "==> ERROR: latest failure"; exit 1',
    )

    # The report prints its error lines after a blank line, below yay's output.
    report = result.stdout.rsplit("\n\n", 1)[-1]
    assert exit_code(result) == 1
    assert "==> ERROR: latest failure" in report


@pytest.mark.parametrize("cancel_signal", [signal.SIGINT, signal.SIGTERM])
def test_cancellation_returns_its_status_and_starts_nothing_later(sandbox, cancel_signal):
    result = run_update(sandbox, f"kill -{cancel_signal.value} $$\nsleep 5")

    assert exit_code(result) == 128 + cancel_signal.value
    assert len(yay_updates(sandbox)) == 1
    assert calls_to(sandbox, "flatpak") == []


def test_flatpak_failure_fails_the_update(sandbox):
    result = run_update(sandbox, "exit 0", flatpak_body="exit 1")

    assert exit_code(result) == 1
    assert "Flatpak" in result.stderr


def test_npmrc_stays_in_place_and_the_override_is_scoped_to_yay(sandbox):
    npmrc = sandbox.root / ".npmrc"
    npmrc.write_text("prefix=/custom/path\n")
    seen = sandbox.root / "yay-env"
    result = run_update(
        sandbox,
        f'''test -f "$HOME/.npmrc" && echo npmrc-present > "{seen}"
for name in NPM_CONFIG_USERCONFIG NPM_CONFIG_PREFIX npm_config_prefix NPM_CONFIG_GLOBALCONFIG npm_config_globalconfig; do
    echo "$name=${{!name-unset}}" >> "{seen}"
done''',
        parent_setup="export NPM_CONFIG_PREFIX=/p npm_config_prefix=/p NPM_CONFIG_GLOBALCONFIG=/g npm_config_globalconfig=/g",
    )

    assert exit_code(result) == 0, result.stderr
    assert seen.read_text().splitlines() == [
        "npmrc-present",
        "NPM_CONFIG_USERCONFIG=/dev/null",
        "NPM_CONFIG_PREFIX=unset",
        "npm_config_prefix=unset",
        "NPM_CONFIG_GLOBALCONFIG=unset",
        "npm_config_globalconfig=unset",
    ]
    assert npmrc.read_text() == "prefix=/custom/path\n"
    assert list(sandbox.root.glob(".npmrc*")) == [npmrc]
    assert "parent-userconfig=unset" in result.stdout


@pytest.mark.parametrize("cancel_signal", [signal.SIGINT, signal.SIGTERM])
def test_flatpak_cancellation_is_reported_as_cancellation(sandbox, cancel_signal):
    result = run_update(sandbox, "exit 0", flatpak_body=f"exit {128 + cancel_signal.value}")

    assert exit_code(result) == 128 + cancel_signal.value
    assert "cancelled" in result.stderr
    assert "Flatpak update failed" not in result.stderr


def signal_running_update(sandbox, body: str, cancel_signal: signal.Signals, step: str = "yay"):
    started = sandbox.root / "step-started"
    cleanup_marks = sandbox.root / "cleanup-marks"
    running_body = f'echo started > "{started}"\n{body}'
    script = (
        update_script(sandbox, "exit 0", pacman_body=running_body)
        if step == "pacman"
        else update_script(sandbox, running_body)
    )
    script = script.replace(
        "start_log_monitor() { :; }",
        f'start_log_monitor() {{ :; }}\nfinish_logging() {{ echo finish >> "{cleanup_marks}"; }}',
    ).replace(
        "stop_log_monitor() { :; }",
        f'stop_log_monitor() {{ echo stop >> "{cleanup_marks}"; }}',
    )
    process = sandbox.start_in_own_session(script)
    deadline = time.monotonic() + 10
    while not started.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    assert started.exists(), f"{step} stub never started"
    os.killpg(process.pid, cancel_signal)
    stdout, stderr = process.communicate(timeout=15)
    marks = cleanup_marks.read_text().splitlines() if cleanup_marks.exists() else []
    return exit_code_from(stdout), stderr, marks


@pytest.mark.parametrize("cancel_signal", [signal.SIGINT, signal.SIGTERM])
def test_signal_to_the_running_update_cleans_up_and_starts_nothing_later(sandbox, cancel_signal):
    returncode, stderr, cleanup_marks = signal_running_update(sandbox, "sleep 30", cancel_signal)

    assert returncode == 128 + cancel_signal.value
    assert cleanup_marks == ["finish", "stop"]
    assert "cancelled" in stderr
    assert len(yay_updates(sandbox)) == 1
    assert calls_to(sandbox, "flatpak") == []


@pytest.mark.parametrize("cancel_signal", [signal.SIGINT, signal.SIGTERM])
def test_signal_during_the_official_update_starts_nothing_later(sandbox, cancel_signal):
    returncode, stderr, cleanup_marks = signal_running_update(sandbox, "sleep 30", cancel_signal, step="pacman")

    assert returncode == 128 + cancel_signal.value
    assert cleanup_marks == ["finish", "stop"]
    assert "cancelled" in stderr
    assert yay_updates(sandbox) == []
    assert calls_to(sandbox, "flatpak") == []


def test_cancellation_blocks_the_retry_even_when_yay_swallows_the_signal(sandbox):
    swallowing_yay = f'''trap 'echo "{CORRUPT_SOURCES}"; exit 1' INT TERM
sleep 30 & wait'''
    returncode, stderr, cleanup_marks = signal_running_update(sandbox, swallowing_yay, signal.SIGINT)

    assert returncode == 130
    assert cleanup_marks == ["finish", "stop"]
    assert len(yay_updates(sandbox)) == 1
    assert calls_to(sandbox, "flatpak") == []


def test_callers_signal_traps_are_restored_after_the_update(sandbox):
    script = update_script(sandbox, "exit 0", parent_setup="trap 'echo menu-trap' INT") + "trap -p INT TERM\n"
    result = sandbox.run(script)

    assert exit_code(result) == 0
    assert "echo menu-trap" in result.stdout
    assert "TERM" not in result.stdout
