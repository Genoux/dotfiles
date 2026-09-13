import subprocess
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
ERRORS_SH = REPO_ROOT / "install/helpers/errors.sh"
INSTALL_SH = REPO_ROOT / "install.sh"
PACKAGE_INSTALL_SH = REPO_ROOT / "lib/package/install.sh"
SETUP_SH = REPO_ROOT / "install/system/setup.sh"


def process_alive(pid: int) -> bool:
    return subprocess.run(["kill", "-0", str(pid)], capture_output=True).returncode == 0


def test_terminate_process_tree_kills_grandchildren_but_not_itself(tmp_path):
    pid_file = tmp_path / "grandchild.pid"
    script = f"""
source "{ERRORS_SH}"
bash -c 'sleep 300 & echo $! > "{pid_file}"; wait' &
for _ in $(seq 50); do [[ -s "{pid_file}" ]] && break; sleep 0.1; done
terminate_process_tree $$
echo survived
"""
    result = subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=20)

    assert "survived" in result.stdout
    grandchild_pid = int(pid_file.read_text())
    for _ in range(20):
        if not process_alive(grandchild_pid):
            break
        time.sleep(0.1)
    assert not process_alive(grandchild_pid)


def test_install_traps_interrupts():
    assert "trap handle_install_interrupt INT TERM" in INSTALL_SH.read_text()


def test_makepkg_config_is_installed_before_the_aur_phase():
    package_install = PACKAGE_INSTALL_SH.read_text()

    assert package_install.index("install/system/makepkg.sh") < package_install.index(
        "install_aur_packages aur_packages"
    )
    assert "makepkg.sh" not in SETUP_SH.read_text()
