#!/bin/bash
# Hardware-specific package selection
# Static, committed manifests (packages/hardware/*.package) selected by
# detected hardware — never generated. Generating from `pacman -Qq` (what's
# already installed) produced empty manifests on a fresh machine, since
# nothing is installed yet to scan.

HARDWARE_MANIFEST_DIR="$DOTFILES_DIR/packages/hardware"

# Detect CPU vendor
_detect_cpu_vendor() {
    if grep -qi "GenuineIntel" /proc/cpuinfo; then
        echo "intel"
    elif grep -qi "AuthenticAMD" /proc/cpuinfo; then
        echo "amd"
    else
        echo "unknown"
    fi
}

# Append one manifest file's packages (skipping comments/blanks) to arr_name.
# The single read path every hardware manifest goes through, official or AUR.
_append_hardware_manifest() {
    local file="$1"
    local -n append_ref=$2

    [[ -f "$file" ]] || return 0

    while IFS= read -r pkg; do
        [[ -z "$pkg" ]] && continue
        [[ "$pkg" =~ ^#.*$ ]] && continue
        append_ref+=("$pkg")
    done < "$file"
}

# Read every static official (non-AUR) hardware manifest that applies to
# this machine into arr_name. Shared by hardware_packages_setup (standalone
# install) and lib/package/install-official.sh (merged into the one official
# -Syu) — the official phase always sees exactly what hardware_detect
# selected, since both call this same function.
read_hardware_official_packages() {
    local -n hw_official_ref=$1
    # shellcheck disable=SC2034  # populated via the nameref passed through
    # to _append_hardware_manifest below, not referenced by name here.
    hw_official_ref=()

    case "$(_detect_cpu_vendor)" in
        amd) _append_hardware_manifest "$HARDWARE_MANIFEST_DIR/amd-ucode.package" hw_official_ref ;;
        intel) _append_hardware_manifest "$HARDWARE_MANIFEST_DIR/intel-ucode.package" hw_official_ref ;;
    esac

    has_nvidia_gpu && _append_hardware_manifest "$HARDWARE_MANIFEST_DIR/nvidia.package" hw_official_ref
    has_amd_gpu && _append_hardware_manifest "$HARDWARE_MANIFEST_DIR/amd.package" hw_official_ref
    has_intel_gpu && _append_hardware_manifest "$HARDWARE_MANIFEST_DIR/intel.package" hw_official_ref
    return 0
}

# Read every static AUR hardware manifest that applies to this machine into
# arr_name. Nothing currently needs one (packages/hardware/<vendor>-aur.package
# doesn't exist for any vendor yet) — this is the one place to add it if a
# future driver ever does, without touching install-aur.sh.
read_hardware_aur_packages() {
    local -n hw_aur_ref=$1
    # shellcheck disable=SC2034  # populated via the nameref passed through
    # to _append_hardware_manifest below, not referenced by name here.
    hw_aur_ref=()

    has_nvidia_gpu && _append_hardware_manifest "$HARDWARE_MANIFEST_DIR/nvidia-aur.package" hw_aur_ref
    has_amd_gpu && _append_hardware_manifest "$HARDWARE_MANIFEST_DIR/amd-aur.package" hw_aur_ref
    has_intel_gpu && _append_hardware_manifest "$HARDWARE_MANIFEST_DIR/intel-aur.package" hw_aur_ref
    return 0
}

# Detect hardware and report it. During `./dotfiles install` this only
# detects — no pacman/yay calls — so it's safe to run before preflight
# (which validates package names against exactly what read_hardware_*
# above will select) and it never sits in the partial-upgrade window between
# a `pacman -Sy` and the official `-Syu`. Standalone (`./dotfiles hardware
# setup`) is the one case that also installs immediately, since there's no
# separate official phase after it — via the same install_official_packages/
# install_aur_packages used everywhere else (never a bare `-S`).
hardware_packages_setup() {
    local standalone_mode=false
    if [[ -z "${FULL_INSTALL:-}" ]]; then
        standalone_mode=true
        init_logging "hardware"
        start_log_monitor
        trap 'stop_log_monitor; finish_logging' EXIT INT TERM
    fi

    log_section "Hardware Detection"

    # has_nvidia_gpu/has_amd_gpu/has_intel_gpu all pipe lspci into grep; a
    # missing lspci makes that pipe silently read as "no GPU" (lspci: command
    # not found on stdout, grep finds nothing, exit 1) rather than erroring —
    # which would install zero GPU drivers on a real GPU with no warning at
    # all. Checked once, loudly, here instead.
    if ! command -v lspci &>/dev/null; then
        log_error "lspci not found (pciutils missing) — cannot detect GPU hardware"
        log_info "Run: dotfiles packages install (pciutils is tracked in packages/arch.package)"
        if $standalone_mode; then
            trap - EXIT INT TERM
            stop_log_monitor
            finish_logging
        fi
        return 1
    fi

    local has_nvidia=$(has_nvidia_gpu && echo "true" || echo "false")
    local has_amd=$(has_amd_gpu && echo "true" || echo "false")
    local has_intel=$(has_intel_gpu && echo "true" || echo "false")
    local cpu_vendor=$(_detect_cpu_vendor)

    log_info "Detected GPUs:"
    [[ "$has_nvidia" == "true" ]] && log_success "  ✓ NVIDIA"
    [[ "$has_amd" == "true" ]] && log_success "  ✓ AMD"
    [[ "$has_intel" == "true" ]] && log_success "  ✓ Intel"
    log_info "Detected CPU: $cpu_vendor"
    echo

    if $standalone_mode; then
        log_section "Installing Hardware Packages"
        # Populated and read via `local -n` in read_hardware_*_packages /
        # install_*_packages below, not referenced by name here.
        # shellcheck disable=SC2034
        local hw_official=()
        # shellcheck disable=SC2034
        local hw_aur=()
        read_hardware_official_packages hw_official
        read_hardware_aur_packages hw_aur
        install_official_packages hw_official
        install_aur_packages hw_aur

        hardware_packages_post_install
    fi

    if [[ "$standalone_mode" == "true" ]]; then
        trap - EXIT INT TERM
        stop_log_monitor
        finish_logging
        source "$DOTFILES_DIR/lib/menu.sh"
        show_completion_menu "Hardware setup complete"
    else
        log_success "✓ Hardware detected"
    fi
}

# Driver post-install setup (DKMS build, module load) — must run after the
# hardware packages are actually installed. During `./dotfiles install` that
# means after the official phase, from install/system/hardware-drivers.sh in
# the config phase; hardware_packages_setup calls it directly in standalone
# mode. Idempotent: dkms autoinstall reports "already installed" and modprobe
# on an already-loaded module is a no-op, both safe to re-run. Fails loudly
# (rather than silently continuing) if hardware was detected but its selected
# driver package never actually made it onto the system — that's a real
# install problem, not something to paper over.
hardware_packages_post_install() {
    log_section "Hardware Driver Post-Install Setup"

    if has_nvidia_gpu; then
        if ! pacman -Qi nvidia-open-dkms &>/dev/null; then
            log_error "NVIDIA GPU detected but nvidia-open-dkms is not installed. Run: dotfiles packages install"
            return 1
        fi
        _setup_nvidia_post_install
    fi

    if has_amd_gpu; then
        if ! pacman -Qi vulkan-radeon &>/dev/null; then
            log_error "AMD GPU detected but vulkan-radeon is not installed. Run: dotfiles packages install"
            return 1
        fi
        _setup_amd_post_install
    fi

    if has_intel_gpu; then
        if ! pacman -Qi vulkan-intel &>/dev/null; then
            log_error "Intel GPU detected but vulkan-intel is not installed. Run: dotfiles packages install"
            return 1
        fi
        _setup_intel_post_install
    fi
}

# Internal: NVIDIA post-install setup
_setup_nvidia_post_install() {
    echo
    echo "Setting up NVIDIA drivers..."

    # Build DKMS modules
    echo "Building DKMS modules (this may take a few minutes)..."
    if sudo dkms autoinstall 2>&1 | grep -q "already installed"; then
        log_success "✓ DKMS modules built"
    elif sudo dkms autoinstall >/dev/null 2>&1; then
        log_success "✓ DKMS modules built"
    else
        log_warning "DKMS build may have failed, continuing..."
    fi

    # Never load nvidia_drm in a live graphical session - it takes over DRM
    # from simpledrm/nouveau and causes an immediate blank screen/freeze.
    # A reboot is always required when the display is already up.
    if [[ -n "${WAYLAND_DISPLAY:-}" || -n "${DISPLAY:-}" ]]; then
        log_warning "⚠ Graphical session detected - skipping module load"
        log_warning "⚠ REBOOT REQUIRED for NVIDIA drivers to take effect"
        return
    fi

    # Safe to load modules only in a TTY (no graphical session)
    sudo modprobe nvidia 2>/dev/null || true
    sudo modprobe nvidia_modeset 2>/dev/null || true
    sudo modprobe nvidia_uvm 2>/dev/null || true
    sudo modprobe nvidia_drm 2>/dev/null || true

    if lsmod | grep -q "^nvidia "; then
        log_success "✓ NVIDIA driver loaded"
    else
        log_warning "⚠ REBOOT REQUIRED for NVIDIA drivers to take effect"
    fi
}

# Internal: AMD post-install setup
_setup_amd_post_install() {
    echo
    echo "Setting up AMD drivers..."

    # Load amdgpu module if not already loaded
    if lsmod | grep -q "^amdgpu "; then
        log_success "✓ AMD driver already loaded"
    else
        sudo modprobe amdgpu 2>/dev/null || true
        if lsmod | grep -q "^amdgpu "; then
            log_success "✓ AMD driver loaded"
        else
            log_warning "⚠ AMD driver may need a reboot"
        fi
    fi
}

# Internal: Intel post-install setup
_setup_intel_post_install() {
    echo
    echo "Setting up Intel drivers..."

    # Intel drivers are usually built into the kernel
    if lsmod | grep -q "^i915 "; then
        log_success "✓ Intel driver already loaded"
    else
        log_warning "⚠ Intel driver check skipped (integrated)"
    fi
}

# Show hardware package status
hardware_packages_status() {
    log_section "Hardware Package Status"

    local has_nvidia=$(has_nvidia_gpu && echo "true" || echo "false")
    local has_amd=$(has_amd_gpu && echo "true" || echo "false")
    local has_intel=$(has_intel_gpu && echo "true" || echo "false")

    log_info "Detected GPUs:"
    [[ "$has_nvidia" == "true" ]] && log_success "  ✓ NVIDIA" || log_info "  ✗ NVIDIA"
    [[ "$has_amd" == "true" ]] && log_success "  ✓ AMD" || log_info "  ✗ AMD"
    [[ "$has_intel" == "true" ]] && log_success "  ✓ Intel" || log_info "  ✗ Intel"
    echo

    _show_gpu_packages "nvidia" "$has_nvidia"
    _show_gpu_packages "amd" "$has_amd"
    _show_gpu_packages "intel" "$has_intel"

    # Check gpu.lua (generated by Hyprland setup)
    local conf_file="$HOME/.config/hypr/gpu.lua"
    if [[ -f "$conf_file" ]]; then
        log_success "gpu.lua exists"
    else
        log_warning "gpu.lua missing (run Hyprland setup)"
    fi
}

# Internal: Show GPU package status
_show_gpu_packages() {
    local gpu_type="$1"
    local should_have="$2"

    [[ "$should_have" != "true" ]] && return

    local expected_packages=()
    _append_hardware_manifest "$HARDWARE_MANIFEST_DIR/${gpu_type}.package" expected_packages
    _append_hardware_manifest "$HARDWARE_MANIFEST_DIR/${gpu_type}-aur.package" expected_packages

    [[ ${#expected_packages[@]} -eq 0 ]] && return

    log_info "${gpu_type^^} packages:"
    local missing=0
    for pkg in "${expected_packages[@]}"; do
        if pacman -Qi "$pkg" &>/dev/null; then
            printf "  ✓ %s\n" "$pkg"
        else
            printf "  ✗ %s (missing)\n" "$pkg"
            missing=$((missing + 1))
        fi
    done

    [[ $missing -gt 0 ]] && log_warning "$missing ${gpu_type^^} packages missing"
    echo
}

# Show quick hardware summary for menu header
hardware_show_summary() {
    source "$DOTFILES_DIR/lib/menu.sh"

    local gpus=()
    has_nvidia_gpu && gpus+=("NVIDIA")
    has_amd_gpu && gpus+=("AMD")
    has_intel_gpu && gpus+=("Intel")

    local gpu_str="${gpus[*]:-None detected}"
    local conf_file="$DOTFILES_DIR/stow/hypr/.config/hypr/gpu.lua"
    local conf_status="missing"
    [[ -f "$conf_file" ]] && conf_status="ok"

    show_quick_summary "GPU" "$gpu_str" "gpu.lua" "$conf_status"
}

# Hardware management menu
hardware_menu() {
    source "$DOTFILES_DIR/lib/menu.sh"

    while true; do
        clear_screen "Hardware"
        hardware_show_summary

        local action=$(choose_option \
            "Setup hardware" \
            "Show details" \
            "Back")

        [[ -z "$action" ]] && return

        case "$action" in
            "Setup hardware")
                hardware_packages_setup
                ;;
            "Show details")
                run_operation "" hardware_packages_status
                ;;
            "Back")
                return
                ;;
        esac
    done
}
