import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
LOGGING_SH = REPO_ROOT / "install/helpers/logging.sh"


def run_init_logging(state_dir: Path, monitor_alive: bool) -> str:
    script = f"""
set -e
ensure_directory() {{ mkdir -p "$1"; }}
log_warning() {{ :; }}
source "{LOGGING_SH}"
export DOTFILES_LOG_DIR="{state_dir}"
export DOTFILES_INSTALL_LOG="{state_dir}/install.log"
export DOTFILES_DAILY_LOG="{state_dir}/dotfiles.log"
init_logging install
echo "Installing 40 AUR packages..." >> "$DOTFILES_LOG_FILE"
if {"true" if monitor_alive else "false"}; then
    sleep 30 & export DOTFILES_LOG_MONITOR_PID=$!
fi
bash -c 'source "{LOGGING_SH}"; ensure_directory() {{ mkdir -p "$1"; }}; export DOTFILES_LOG_DIR="{state_dir}" DOTFILES_INSTALL_LOG="{state_dir}/install.log" DOTFILES_DAILY_LOG="{state_dir}/dotfiles.log"; init_logging package; echo "yay output" >> "$DOTFILES_LOG_FILE"'
[[ -n "${{DOTFILES_LOG_MONITOR_PID:-}}" ]] && kill "$DOTFILES_LOG_MONITOR_PID"
cat "{state_dir}/install.log"
"""
    return subprocess.run(["bash", "-c", script], capture_output=True, text=True, check=True).stdout


def test_nested_script_keeps_writing_to_the_monitored_log(tmp_path):
    install_log = run_init_logging(tmp_path, monitor_alive=True)

    assert "Installing 40 AUR packages..." in install_log
    assert "yay output" in install_log
    assert not (tmp_path / "dotfiles.log").exists()


def test_without_a_live_monitor_nested_script_starts_its_own_log(tmp_path):
    install_log = run_init_logging(tmp_path, monitor_alive=False)

    assert "yay output" not in install_log
    assert "yay output" in (tmp_path / "dotfiles.log").read_text()
