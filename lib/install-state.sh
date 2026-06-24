#!/bin/bash
# Installation state management
# Tracks progress, enables resume, and provides rollback capability

STATE_FILE="$HOME/.dotfiles-install-state.json"
SNAPSHOT_DIR="$HOME/.dotfiles-snapshots"

# Installation phases in order
declare -a INSTALL_PHASES=(
    "preflight"
    "hardware_detect"
    "system_prepare"
    "packages_official"
    "packages_aur"
    "config_link"
    "system_config"
    "theme_setup"
    "shell_setup"
    "hyprland_setup"
    "verification"
)

# Initialize state file
init_state() {
    local install_id="${1:-$(date +%s)}"

    mkdir -p "$(dirname "$STATE_FILE")"
    mkdir -p "$SNAPSHOT_DIR"

    cat > "$STATE_FILE" <<EOF
{
  "install_id": "$install_id",
  "start_time": "$(date -Iseconds)",
  "status": "in_progress",
  "current_phase": "init",
  "completed_phases": [],
  "failed_phases": [],
  "snapshots": {},
  "packages_installed": {
    "official": [],
    "aur": []
  },
  "configs_linked": [],
  "rollback_available": false,
  "resume_point": null
}
EOF

    log_info "Initialized installation state: $install_id"
}

# Load state from file
load_state() {
    if [[ ! -f "$STATE_FILE" ]]; then
        return 1
    fi

    # Validate JSON
    if ! jq empty "$STATE_FILE" 2>/dev/null; then
        log_error "Corrupted state file: $STATE_FILE"
        return 1
    fi

    return 0
}

# Get state value
get_state() {
    local key="$1"

    if ! load_state; then
        return 1
    fi

    jq -r ".$key // empty" "$STATE_FILE"
}

# Update state value
update_state() {
    local key="$1"
    local value="$2"

    if ! load_state; then
        init_state
    fi

    local temp_file
    temp_file=$(mktemp)

    jq --arg key "$key" --arg val "$value" \
        'setpath($key | split("."); $val)' \
        "$STATE_FILE" > "$temp_file"

    mv "$temp_file" "$STATE_FILE"
}

# Mark phase as started
start_phase() {
    local phase="$1"

    update_state "current_phase" "$phase"
    update_state "resume_point" "$phase"

    log_section "Phase: $phase"
}

# Mark phase as completed
complete_phase() {
    local phase="$1"

    local temp_file
    temp_file=$(mktemp)

    jq --arg phase "$phase" \
        '.completed_phases += [$phase] | .resume_point = null' \
        "$STATE_FILE" > "$temp_file"

    mv "$temp_file" "$STATE_FILE"

    log_success "✓ Phase completed: $phase"
}

# Mark phase as failed
fail_phase() {
    local phase="$1"
    local error="${2:-unknown error}"

    local temp_file
    temp_file=$(mktemp)

    jq --arg phase "$phase" --arg error "$error" \
        '.failed_phases += [{"phase": $phase, "error": $error, "time": now | todate}] |
         .status = "failed" |
         .resume_point = $phase' \
        "$STATE_FILE" > "$temp_file"

    mv "$temp_file" "$STATE_FILE"

    log_error "✗ Phase failed: $phase ($error)"
}

# Record installed package
record_package() {
    local package="$1"
    local type="${2:-official}"  # official or aur

    local temp_file
    temp_file=$(mktemp)

    jq --arg pkg "$package" --arg type "$type" \
        ".packages_installed.$type += [\$pkg] | .packages_installed.$type |= unique" \
        "$STATE_FILE" > "$temp_file"

    mv "$temp_file" "$STATE_FILE"
}

# Record linked config
record_config() {
    local config="$1"

    local temp_file
    temp_file=$(mktemp)

    jq --arg cfg "$config" \
        '.configs_linked += [$cfg] | .configs_linked |= unique' \
        "$STATE_FILE" > "$temp_file"

    mv "$temp_file" "$STATE_FILE"
}

# List dotfiles-managed stow symlinks under existing home config dirs.
# Best-effort and pipefail-safe: skips missing dirs and swallows find errors
# so callers running under `set -e` are never aborted by the scan (a fresh
# machine may not have ~/.config or ~/.local yet).
list_stow_symlinks() {
    local search_dirs=()
    [[ -d "$HOME/.config" ]] && search_dirs+=("$HOME/.config")
    [[ -d "$HOME/.local" ]] && search_dirs+=("$HOME/.local")
    [[ ${#search_dirs[@]} -eq 0 ]] && return 0

    local link target
    while IFS= read -r link; do
        target=$(readlink "$link")
        [[ "$target" == *"dotfiles/stow"* ]] && echo "$link -> $target"
    done < <(find "${search_dirs[@]}" -type l 2>/dev/null || true)
}

# Create snapshot before phase
create_snapshot() {
    local phase="$1"
    local snapshot_id="${phase}_$(date +%s)"

    log_info "Creating snapshot: $snapshot_id"

    # Snapshot package list
    local pkg_snapshot="$SNAPSHOT_DIR/${snapshot_id}_packages.txt"
    pacman -Qq > "$pkg_snapshot"

    # Snapshot explicitly installed packages
    local explicit_snapshot="$SNAPSHOT_DIR/${snapshot_id}_explicit.txt"
    pacman -Qeq > "$explicit_snapshot"

    # Snapshot stow links
    local stow_snapshot="$SNAPSHOT_DIR/${snapshot_id}_stow.txt"
    list_stow_symlinks > "$stow_snapshot"

    # Update state with snapshot info
    local temp_file
    temp_file=$(mktemp)

    jq --arg phase "$phase" --arg snapshot "$snapshot_id" \
        '.snapshots[$phase] = {
            "id": $snapshot,
            "time": now | todate,
            "packages": ($snapshot + "_packages.txt"),
            "explicit": ($snapshot + "_explicit.txt"),
            "stow": ($snapshot + "_stow.txt")
        } | .rollback_available = true' \
        "$STATE_FILE" > "$temp_file"

    mv "$temp_file" "$STATE_FILE"

    log_success "✓ Snapshot created: $snapshot_id"
}

# Rollback to snapshot
rollback_to_phase() {
    local phase="$1"

    log_section "Rolling Back to $phase"

    if ! load_state; then
        log_error "No state file found"
        return 1
    fi

    local snapshot_id
    snapshot_id=$(jq -r ".snapshots.\"$phase\".id // empty" "$STATE_FILE")

    if [[ -z "$snapshot_id" ]]; then
        log_error "No snapshot found for phase: $phase"
        return 1
    fi

    log_info "Snapshot: $snapshot_id"

    # Rollback packages
    local pkg_snapshot="$SNAPSHOT_DIR/${snapshot_id}_packages.txt"
    local explicit_snapshot="$SNAPSHOT_DIR/${snapshot_id}_explicit.txt"

    if [[ -f "$explicit_snapshot" ]]; then
        log_info "Rolling back packages..."

        # Find packages to remove (installed since snapshot)
        local to_remove=()
        while IFS= read -r pkg; do
            if ! grep -Fxq "$pkg" "$pkg_snapshot" 2>/dev/null; then
                to_remove+=("$pkg")
            fi
        done < <(pacman -Qq)

        if [[ ${#to_remove[@]} -gt 0 ]]; then
            log_info "Removing ${#to_remove[@]} packages installed since snapshot..."
            sudo pacman -Rns --noconfirm "${to_remove[@]}" 2>&1 | tee -a "${DOTFILES_LOG_FILE:-/dev/null}"
        fi
    fi

    # Rollback stow links
    local stow_snapshot="$SNAPSHOT_DIR/${snapshot_id}_stow.txt"

    if [[ -f "$stow_snapshot" ]]; then
        log_info "Rolling back configuration links..."

        # Remove links that weren't in snapshot
        local link
        while IFS= read -r link; do
            link="${link%% -> *}"
            if ! grep -Fq "$link ->" "$stow_snapshot" 2>/dev/null; then
                log_info "Removing link: ${link/#$HOME/~}"
                rm "$link"
            fi
        done < <(list_stow_symlinks)
    fi

    # Update state
    update_state "status" "rolled_back"
    update_state "current_phase" "$phase"

    log_success "✓ Rolled back to phase: $phase"
}

# Check if can resume
can_resume() {
    if ! load_state; then
        return 1
    fi

    local status
    status=$(get_state "status")

    [[ "$status" == "failed" || "$status" == "in_progress" ]]
}

# Get resume point
get_resume_point() {
    if ! can_resume; then
        return 1
    fi

    get_state "resume_point"
}

# Check if phase is completed
is_phase_completed() {
    local phase="$1"

    if ! load_state; then
        return 1
    fi

    jq -e ".completed_phases | index(\"$phase\")" "$STATE_FILE" >/dev/null
}

# Mark installation as complete
mark_complete() {
    update_state "status" "completed"
    update_state "end_time" "$(date -Iseconds)"
    update_state "current_phase" "complete"
    update_state "resume_point" "null"

    log_success "Installation marked as complete"
}

# Show installation state
show_state() {
    if ! load_state; then
        log_info "No installation state found"
        return
    fi

    log_section "Installation State"

    local install_id status start_time current_phase
    install_id=$(get_state "install_id")
    status=$(get_state "status")
    start_time=$(get_state "start_time")
    current_phase=$(get_state "current_phase")

    show_info "Install ID" "$install_id"
    show_info "Status" "$status"
    show_info "Started" "$start_time"
    show_info "Current Phase" "$current_phase"

    echo
    log_info "Completed Phases:"
    jq -r '.completed_phases[]' "$STATE_FILE" | while read -r phase; do
        echo "  ✓ $phase"
    done

    echo
    local failed_count
    failed_count=$(jq '.failed_phases | length' "$STATE_FILE")

    if [[ $failed_count -gt 0 ]]; then
        log_warning "Failed Phases:"
        jq -r '.failed_phases[] | "  ✗ \(.phase): \(.error)"' "$STATE_FILE"
        echo
    fi

    if can_resume; then
        local resume_point
        resume_point=$(get_resume_point)
        log_info "Can resume from: $resume_point"
    fi
}

# Clear state (for fresh install)
clear_state() {
    if [[ -f "$STATE_FILE" ]]; then
        local backup="$STATE_FILE.$(date +%s).bak"
        mv "$STATE_FILE" "$backup"
        log_info "State backed up to: $backup"
    fi

    log_success "State cleared"
}
