import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
LOGGING_SH = REPO_ROOT / "install/helpers/logging.sh"


def bash(script: str) -> subprocess.CompletedProcess:
    return subprocess.run(["bash", "-c", script], capture_output=True, text=True)


def logging_prelude(state_dir: Path) -> str:
    return f"""
ensure_directory() {{ mkdir -p "$1"; }}
log_warning() {{ :; }}
source "{LOGGING_SH}"
export DOTFILES_LOG_DIR="{state_dir}"
export DOTFILES_INSTALL_LOG="{state_dir}/install.log"
export DOTFILES_DAILY_LOG="{state_dir}/dotfiles.log"
"""


def nested(state_dir: Path, body: str, keep_session: bool = True) -> str:
    unset_session = "" if keep_session else "env -u DOTFILES_LOG_SESSION_PID "
    return f"{unset_session}bash <<'NESTED'\n{logging_prelude(state_dir)}{body}\nNESTED\n"


def test_nested_script_keeps_writing_to_the_parent_session_log(tmp_path):
    result = bash(
        logging_prelude(tmp_path)
        + "init_logging install\n"
        + 'echo "Installing 40 AUR packages..." >> "$DOTFILES_LOG_FILE"\n'
        + nested(tmp_path, 'init_logging package; echo "yay output" >> "$DOTFILES_LOG_FILE"')
    )

    assert result.returncode == 0, result.stderr
    install_log = (tmp_path / "install.log").read_text()
    assert "Installing 40 AUR packages..." in install_log
    assert "yay output" in install_log
    assert not (tmp_path / "dotfiles.log").exists()


def test_standalone_script_starts_its_own_log(tmp_path):
    result = bash(
        logging_prelude(tmp_path)
        + "init_logging install\n"
        + nested(tmp_path, 'init_logging package; echo "yay output" >> "$DOTFILES_LOG_FILE"', keep_session=False)
    )

    assert result.returncode == 0, result.stderr
    assert "yay output" not in (tmp_path / "install.log").read_text()
    assert "yay output" in (tmp_path / "dotfiles.log").read_text()


def test_logged_commands_leave_plain_text_in_the_log(tmp_path):
    result = bash(
        logging_prelude(tmp_path)
        + "init_logging install\n"
        + "run_command_logged demo printf '\\033[1;32mgreen\\033[0m\\n 10%%\\r100%% done\\n\\033[?25lcursor\\n'\n"
    )

    assert result.returncode == 0, result.stderr
    install_log = (tmp_path / "install.log").read_text()
    assert "\x1b" not in install_log
    assert "\r" not in install_log
    assert "green" in install_log
    assert "100% done" in install_log


def test_run_command_logged_returns_the_command_status_under_errexit(tmp_path):
    result = bash(
        "set -eEo pipefail\n"
        + logging_prelude(tmp_path)
        + "init_logging install\n"
        + "status=0; run_command_logged failing false || status=$?\n"
        + 'echo "status=$status"\n'
    )

    assert result.returncode == 0, result.stderr
    assert "status=1" in result.stdout


def test_nested_stop_neither_kills_the_monitor_nor_writes_the_log_into_itself(tmp_path):
    result = bash(
        logging_prelude(tmp_path)
        + "init_logging install\n"
        + 'echo "line one" >> "$DOTFILES_LOG_FILE"\n'
        + "sleep 30 & export DOTFILES_LOG_MONITOR_PID=$! DOTFILES_LOG_MONITOR_OWNER=$$\n"
        + 'run_command_logged nested bash -c \'source "' + str(LOGGING_SH) + '"; start_log_monitor; stop_log_monitor true\'\n'
        + 'kill -0 "$DOTFILES_LOG_MONITOR_PID" && echo monitor-alive\n'
        + 'kill "$DOTFILES_LOG_MONITOR_PID"\n'
    )

    assert result.returncode == 0, result.stderr
    assert "monitor-alive" in result.stdout
    install_log = (tmp_path / "install.log").read_text()
    assert install_log.count("line one") == 1
    assert "Full log" not in install_log
