from conftest import source


def test_official_parsing_skips_comments_and_blanks(sandbox):
    sandbox.write_package_file(
        "arch.package", ["# a comment", "", "base", "", "git", "# trailing"]
    )
    sandbox.stub("lspci", "true")
    sandbox.stub("lsmod", "true")
    result = sandbox.run(
        f"""
{source("install/helpers/hardware.sh", "lib/hardware-packages.sh", "lib/package/install-official.sh")}
packages=()
read_official_install_packages packages
printf '%s\\n' "${{packages[@]}}"
"""
    )
    assert result.returncode == 0, result.stderr
    names = result.stdout.splitlines()
    assert "base" in names
    assert "git" in names
    # No hardware manifests exist in this fixture — whatever CPU microcode
    # (if any) the real machine's /proc/cpuinfo selects is the only thing
    # that could add to "base"/"git", and no such file exists here either.
    assert len(names) == 2


def test_official_parsing_merges_only_the_selected_hardware_manifest(sandbox):
    # Static manifests are selected by detection, not globbed wholesale — an
    # AMD-detected machine must pick up amd.package and skip nvidia.package/
    # intel.package even though all three files exist in the repo. CPU
    # microcode is left out of this fixture on purpose: which ucode file (if
    # any) merges in depends on the real machine's /proc/cpuinfo, which a
    # userspace test can't fake, so asserting on it here would be flaky.
    sandbox.write_package_file("arch.package", ["base"])
    sandbox.write_package_file("hardware/amd.package", ["vulkan-radeon"])
    sandbox.write_package_file("hardware/nvidia.package", ["nvidia-utils"])
    sandbox.write_package_file("hardware/intel.package", ["vulkan-intel"])
    sandbox.stub("lspci", "printf '02:00.0 VGA: Advanced Micro Devices [AMD/ATI]\\n'")
    sandbox.stub("lsmod", "true")

    result = sandbox.run(
        f"""
{source("install/helpers/hardware.sh", "lib/hardware-packages.sh", "lib/package/install-official.sh")}
packages=()
read_official_install_packages packages
printf '%s\\n' "${{packages[@]}}"
"""
    )
    assert result.returncode == 0, result.stderr
    names = result.stdout.splitlines()
    assert "base" in names
    assert "vulkan-radeon" in names
    assert "nvidia-utils" not in names
    assert "vulkan-intel" not in names


def test_aur_parsing_skips_comments_and_blanks(sandbox):
    sandbox.write_package_file("aur.package", ["# comment", "yay", "", "matugen-bin"])
    sandbox.stub("lspci", "true")
    sandbox.stub("lsmod", "true")
    result = sandbox.run(
        f"""
{source("install/helpers/hardware.sh", "lib/hardware-packages.sh", "lib/package/install-aur.sh")}
pkgs=()
read_aur_install_packages pkgs
printf '%s\\n' "${{pkgs[@]}}"
"""
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == ["yay", "matugen-bin"]


def test_custom_package_parsing_skips_comments_and_blanks(sandbox):
    sandbox.write_package_file(
        "custom.package", ["# owner/repo per line", "Genoux/flow", "", "Genoux/idleon-desktop"]
    )
    result = sandbox.run(
        f"""
{source("lib/package/custom.sh")}
repos=()
read_custom_packages repos
printf '%s\\n' "${{repos[@]}}"
"""
    )
    assert result.returncode == 0, result.stderr
    assert result.stdout.splitlines() == ["Genoux/flow", "Genoux/idleon-desktop"]
