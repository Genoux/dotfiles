from pathlib import Path

from conftest import source

REPO = Path(__file__).resolve().parents[2]


def _pacman_calls(sandbox):
    return [c for c in sandbox.calls() if c.split()[0] == "pacman"]


def _assert_no_partial_install_after_sync(pacman_calls):
    """No bare `-S` (without `u`) may appear after a `-Sy` unless a `-Syu`
    came in between — that's exactly the partial-upgrade window Arch warns
    against, and the origin of the nodejs-lts-iron vs nodejs conflict this
    fix addresses."""
    synced_ahead_of_system = False
    for call in pacman_calls:
        args = call.split()[1:]
        if not args:
            continue
        flag = args[0]
        if flag == "-Syu":
            synced_ahead_of_system = False
        elif flag == "-Sy":
            synced_ahead_of_system = True
        elif flag == "-S" and synced_ahead_of_system:
            raise AssertionError(f"partial install while synced-ahead: {call!r} in {pacman_calls}")


def test_install_sh_bootstrap_uses_full_upgrade_not_partial_install():
    lines = (REPO / "install.sh").read_text().splitlines()
    bootstrap_lines = [l for l in lines if "MISSING_DEPS[@]" in l and "pacman" in l]
    assert len(bootstrap_lines) == 1, bootstrap_lines
    assert "pacman -Syu --needed --noconfirm" in bootstrap_lines[0]


def test_full_packages_phase_never_partial_installs_after_a_sync(sandbox):
    sandbox.write_package_file("arch.package", ["base-devel", "git", "nodejs", "npm"])
    sandbox.write_package_file("aur.package", ["some-aur-pkg"])

    # Bootstrap deps (install.sh) are already present in this scenario, so no
    # pacman call happens for them — the interesting case is when they ARE
    # missing, covered by the static test above (a full simulation of
    # install.sh's sudo-keepalive/state machinery is out of scope here).
    #
    # yay is pre-seeded as already installed (rather than simulated from
    # scratch via git clone + makepkg) so this test doesn't depend on whether
    # the machine running it happens to already have a real yay on PATH
    # ahead of the sandbox bin dir.
    sandbox.stub("yay", "", log=True)
    sandbox.stub(
        "pacman",
        """
case "$1" in
    -Sy) exit 0 ;;
    -Syu) exit 0 ;;
    -Si)
        shift
        [ "$1" = "--" ] && shift
        for name in "$@"; do
            printf "Name            : %s\\n" "$name"
        done
        exit 0
        ;;
    *) exit 0 ;;
esac
""",
    )

    result = sandbox.run(
        f"""
{source("lib/package/preflight.sh", "lib/package/core.sh", "lib/package/install-official.sh", "lib/package/install-aur.sh", "lib/package/install.sh")}
sync_pacman_db
official=(base-devel git nodejs npm)
install_official_packages official
aur=(some-aur-pkg)
install_aur_packages aur
echo "exit=$?"
""",
        timeout=30,
    )
    assert "exit=0" in result.stdout, result.stdout + result.stderr

    calls = sandbox.calls()
    pacman_calls = _pacman_calls(sandbox)
    _assert_no_partial_install_after_sync(pacman_calls)

    syu_index = next(i for i, c in enumerate(calls) if c.startswith("pacman -Syu"))
    yay_index = next(i for i, c in enumerate(calls) if c.startswith("yay "))
    assert syu_index < yay_index, "yay must only run after the official -Syu"


def test_ensure_yay_installed_only_called_from_aur_phase_not_prepare():
    # The static-order guarantee behind "yay bootstrap happens after the
    # official -Syu": packages_prepare (called before the official install)
    # must not call ensure_yay_installed itself — only install_aur_packages
    # does, and that runs strictly after install_official_packages in
    # packages_install (lib/package/install.sh).
    core = (REPO / "lib/package/core.sh").read_text()
    prepare_body = core[core.index("packages_prepare()") :]
    code_lines = [l for l in prepare_body.splitlines() if not l.strip().startswith("#")]
    assert not any("ensure_yay_installed" in l for l in code_lines)

    aur_sh = (REPO / "lib/package/install-aur.sh").read_text()
    assert "ensure_yay_installed" in aur_sh

    orchestration = (REPO / "lib/package/install.sh").read_text()
    official_call = orchestration.index("install_official_packages packages")
    aur_call = orchestration.index("install_aur_packages aur_packages")
    assert official_call < aur_call


def test_full_phase_sequence_including_hardware_detect_never_partial_installs(sandbox):
    # Simulates the real install.sh order: hardware_detect (detection only,
    # no pacman/yay calls, FULL_INSTALL=true) -> preflight (multilib, sync,
    # name validation) -> official install -> AUR install. An NVIDIA+AMD
    # machine is stubbed via lspci (has_nvidia_gpu/has_amd_gpu read it); the
    # nvidia/amd manifests are static fixtures written directly, since the
    # real files are selected by detection, not generated from what's
    # installed. CPU vendor is left to the real machine's /proc/cpuinfo
    # (can't be faked from userspace) with no ucode fixture files present, so
    # whichever vendor is detected contributes nothing extra to check.
    sandbox.write_package_file("arch.package", ["base-devel", "git", "nodejs", "npm", "linux-headers"])
    sandbox.write_package_file("aur.package", [])
    sandbox.write_package_file("hardware/nvidia.package", ["nvidia-open-dkms", "nvidia-utils"])
    sandbox.write_package_file("hardware/amd.package", ["vulkan-radeon"])

    sandbox.stub(
        "lspci",
        r"""
printf '01:00.0 VGA compatible controller: NVIDIA Corporation Device 2504\n'
printf '02:00.0 VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI] Device 164e\n'
""",
    )
    sandbox.stub("lsmod", "true")
    sandbox.stub("dkms", "true")
    sandbox.stub("yay", "", log=True)
    fake_pacman_conf = sandbox.root / "pacman.conf"
    fake_pacman_conf.write_text("[multilib]\nInclude = /etc/pacman.d/mirrorlist\n")
    sandbox.stub("pacman-conf", "exit 0")
    sandbox.stub(
        "pacman",
        """
case "$1" in
    -Sy) exit 0 ;;
    -Syu) exit 0 ;;
    -Si)
        shift
        [ "$1" = "--" ] && shift
        for name in "$@"; do
            printf "Name            : %s\\n" "$name"
        done
        exit 0
        ;;
    *) exit 0 ;;
esac
""",
    )

    result = sandbox.run(
        f"""
export FULL_INSTALL=true
export PACMAN_CONF="{fake_pacman_conf}"
{source("install/helpers/hardware.sh", "lib/hardware-packages.sh", "lib/package/preflight.sh", "lib/package/core.sh", "lib/package/install-official.sh", "lib/package/install-aur.sh", "lib/package/install.sh")}
hardware_packages_setup
ensure_multilib_enabled
sync_pacman_db
official=()
read_official_install_packages official
install_official_packages official
aur=()
read_aur_install_packages aur
install_aur_packages aur
echo "exit=$?"
""",
        timeout=30,
    )
    assert "exit=0" in result.stdout, result.stdout + result.stderr

    calls = sandbox.calls()
    pacman_calls = _pacman_calls(sandbox)
    _assert_no_partial_install_after_sync(pacman_calls)

    # hardware_detect itself must not touch pacman/yay at all in FULL_INSTALL
    # mode — it only detects and logs.
    hardware_detect_calls = [c for c in calls if c.split()[0] in ("pacman", "yay")]
    for call in hardware_detect_calls:
        assert not call.startswith("yay "), f"hardware_detect must not call yay: {call!r}"

    syu_calls = [c for c in calls if c.startswith("pacman -Syu")]
    assert len(syu_calls) == 2, syu_calls
    syu_calls = syu_calls[1:]
    assert "nvidia-open-dkms" in syu_calls[0]
    assert "nvidia-utils" in syu_calls[0]
    assert "vulkan-radeon" in syu_calls[0]
    assert "linux-headers" in syu_calls[0]


def test_intel_only_selects_only_the_intel_manifest(sandbox):
    sandbox.write_package_file("arch.package", ["base"])
    sandbox.write_package_file("aur.package", [])
    sandbox.write_package_file("hardware/nvidia.package", ["nvidia-open-dkms"])
    sandbox.write_package_file("hardware/amd.package", ["vulkan-radeon"])
    sandbox.write_package_file("hardware/intel.package", ["vulkan-intel"])
    sandbox.stub("lspci", r"printf '00:02.0 VGA compatible controller: Intel Corporation Device a7a1\n'")
    sandbox.stub("lsmod", "true")

    result = sandbox.run(
        f"""
{source("install/helpers/hardware.sh", "lib/hardware-packages.sh")}
official=()
read_hardware_official_packages official
printf '%s\\n' "${{official[@]}}"
"""
    )
    assert result.returncode == 0, result.stderr
    names = result.stdout.splitlines()
    assert "vulkan-intel" in names
    assert "nvidia-open-dkms" not in names
    assert "vulkan-radeon" not in names


def test_no_gpu_detected_selects_no_gpu_packages(sandbox):
    sandbox.write_package_file("hardware/nvidia.package", ["nvidia-open-dkms"])
    sandbox.write_package_file("hardware/amd.package", ["vulkan-radeon"])
    sandbox.write_package_file("hardware/intel.package", ["vulkan-intel"])
    sandbox.stub("lspci", "true")
    sandbox.stub("lsmod", "true")

    result = sandbox.run(
        f"""
{source("install/helpers/hardware.sh", "lib/hardware-packages.sh")}
official=()
read_hardware_official_packages official
printf '%s\\n' "${{official[@]}}"
"""
    )
    assert result.returncode == 0, result.stderr
    gpu_names = {"nvidia-open-dkms", "vulkan-radeon", "vulkan-intel"}
    assert not (gpu_names & set(result.stdout.splitlines()))


def test_microcode_matches_detected_cpu_vendor(sandbox):
    sandbox.write_package_file("hardware/amd-ucode.package", ["amd-ucode"])
    sandbox.write_package_file("hardware/intel-ucode.package", ["intel-ucode"])
    sandbox.stub("lspci", "true")
    sandbox.stub("lsmod", "true")

    result = sandbox.run(
        f"""
{source("install/helpers/hardware.sh", "lib/hardware-packages.sh")}
official=()
read_hardware_official_packages official
printf '%s\\n' "${{official[@]}}"
"""
    )
    assert result.returncode == 0, result.stderr
    names = set(result.stdout.splitlines())
    # Whichever vendor this test machine reports, exactly one ucode package
    # must be selected — never both, never neither.
    assert len(names & {"amd-ucode", "intel-ucode"}) == 1


def test_hardware_detect_fails_loudly_when_lspci_is_missing(sandbox):
    # Under a restricted PATH (lspci genuinely absent, not just unstubbed —
    # not stubbing it would still find the real system lspci later in PATH),
    # has_nvidia_gpu/has_amd_gpu/has_intel_gpu's `lspci | grep ...` pipe would
    # otherwise silently read as "no GPU" (lspci: command not found on
    # stdout, grep finds nothing, exit 1) rather than erroring — installing
    # zero GPU drivers on a real GPU with no warning at all.
    sandbox.write_package_file("hardware/nvidia.package", ["nvidia-open-dkms"])

    result = sandbox.run(
        f"""
export FULL_INSTALL=true
{source("lib/hardware-packages.sh")}
hardware_packages_setup
echo "exit=$?"
""",
        restrict_path=True,
    )
    assert "exit=1" in result.stdout, result.stdout + result.stderr
    assert "lspci" in result.stderr


def test_bootstrap_dependencies_include_pciutils():
    lines = (REPO / "install.sh").read_text().splitlines()
    dep_line = next(l for l in lines if l.strip().startswith("for dep in"))
    assert "pciutils" in dep_line


def test_packages_prepare_has_no_partial_install_calls():
    content = (REPO / "lib/package/core.sh").read_text()
    code_lines = [l for l in content.splitlines() if not l.strip().startswith("#")]
    for line in code_lines:
        if "pacman -S " in line or "pacman -S --" in line:
            raise AssertionError(f"partial install call left in core.sh: {line!r}")
    assert "ensure_nodejs_installed" not in content


def test_amd_hardware_selection_succeeds_under_errexit(sandbox):
    sandbox.write_package_file('arch.package', ['base'])
    sandbox.write_package_file('aur.package', [])
    sandbox.write_package_file('hardware/amd.package', ['vulkan-radeon'])
    sandbox.stub('lspci', "echo 'VGA compatible controller: Advanced Micro Devices, Inc. [AMD/ATI]'")
    result = sandbox.run(f"""
set -e
{source('install/helpers/hardware.sh', 'lib/hardware-packages.sh', 'lib/package/install-official.sh', 'lib/package/install-aur.sh')}
packages=()
aur=()
read_official_install_packages packages
read_aur_install_packages aur
printf '%s\\n' "${{packages[@]}}"
""")
    assert result.returncode == 0, result.stderr
    assert 'vulkan-radeon' in result.stdout
