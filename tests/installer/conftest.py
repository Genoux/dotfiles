import os
import shlex
import shutil
import stat
import subprocess
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]

STUB_LOGGERS = """
log_info() { printf 'INFO: %s\\n' "$*" >&2; }
log_warning() { printf 'WARN: %s\\n' "$*" >&2; }
log_error() { printf 'ERROR: %s\\n' "$*" >&2; }
log_success() { printf 'OK: %s\\n' "$*" >&2; }
log_section() { printf '== %s ==\\n' "$*" >&2; }
fatal_error() { printf 'FATAL: %s\\n' "$*" >&2; return 1; }
run_command_logged() { shift; "$@"; }
ensure_sudo() { sudo -v; }
init_logging() { :; }
start_log_monitor() { :; }
stop_log_monitor() { :; }
finish_logging() { :; }
"""


class BashSandbox:
    """A temp dir with a stubbed PATH and a call log every stub appends to."""

    def __init__(self, tmp_path: Path):
        self.root = tmp_path
        self.bin_dir = tmp_path / "bin"
        self.bin_dir.mkdir()
        self.calls_log = tmp_path / "calls.log"
        self.calls_log.write_text("")
        self.dotfiles_dir = tmp_path / "dotfiles"
        shutil.copytree(REPO / "lib", self.dotfiles_dir / "lib")
        shutil.copytree(REPO / "install", self.dotfiles_dir / "install")
        (self.dotfiles_dir / "packages").mkdir()

        # sudo is transparent in the sandbox — the "system" paths under test
        # are all inside tmp_path, owned by the test user already. `-v`
        # (refresh/validate the cached credential, run nothing) is handled
        # specially: bash's `exec` builtin would otherwise try to parse it as
        # its own flag instead of a command to run.
        self.stub("sudo", '[ "$1" = "-v" ] && exit 0\nexec "$@"')

    def stub(self, name: str, body: str, exit_code: int = 0, log: bool = True):
        path = self.bin_dir / name
        logging_line = (
            f'printf "%s" "{name}" >> "{self.calls_log}"; '
            f'for a in "$@"; do printf " %s" "$a" >> "{self.calls_log}"; done; '
            f'printf "\\n" >> "{self.calls_log}"\n'
            if log
            else ""
        )
        script = f"#!/bin/bash\n{logging_line}{body}\nexit {exit_code}\n"
        path.write_text(script)
        path.chmod(path.stat().st_mode | stat.S_IEXEC)

    def write_package_file(self, name: str, lines):
        path = self.dotfiles_dir / "packages" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("\n".join(lines) + "\n" if lines else "")

    def calls(self):
        if not self.calls_log.exists():
            return []
        return [line for line in self.calls_log.read_text().splitlines() if line]

    def run(self, script: str, timeout: int = 20, restrict_path: bool = False) -> subprocess.CompletedProcess:
        env = dict(os.environ)
        # restrict_path=True: PATH is *only* the stub bin dir, none of the
        # real system's binaries — for simulating a command being entirely
        # absent (e.g. lspci without pciutils), which merely not stubbing it
        # can't do since the real one is still reachable later in PATH. bash
        # itself still needs to be resolved to launch the script at all, so
        # its real (unrestricted) path is used as the executable directly.
        bash_executable = shutil.which("bash")
        env["PATH"] = str(self.bin_dir) if restrict_path else f"{self.bin_dir}:{env['PATH']}"
        env["DOTFILES_DIR"] = str(self.dotfiles_dir)
        env["PACKAGES_FILE"] = str(self.dotfiles_dir / "packages/arch.package")
        env["AUR_PACKAGES_FILE"] = str(self.dotfiles_dir / "packages/aur.package")
        env["HOME"] = str(self.root)
        for kind in ("CACHE", "CONFIG", "DATA", "STATE"):
            env[f"XDG_{kind}_HOME"] = str(self.root / {"CACHE": ".cache", "CONFIG": ".config", "DATA": ".local/share", "STATE": ".local/state"}[kind])
        env["DOTFILES_LOG_FILE"] = str(self.root / "dotfiles.log")
        full_script = f"set -uo pipefail\n{STUB_LOGGERS}\n{script}\n"
        return subprocess.run(
            [bash_executable, "-c", full_script],
            capture_output=True,
            text=True,
            timeout=timeout,
            env=env,
        )


@pytest.fixture
def sandbox(tmp_path):
    return BashSandbox(tmp_path)


def source(*relative_paths: str) -> str:
    return "\n".join(f'source "$DOTFILES_DIR/{p}"' for p in relative_paths)
