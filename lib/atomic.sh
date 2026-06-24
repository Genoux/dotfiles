#!/bin/bash
# Atomic installation operations
# Provides transaction-like semantics for dotfiles installation

STAGING_DIR="$HOME/.dotfiles-staging"
BACKUP_DIR="$HOME/.dotfiles-backup"
ATOMIC_STATE="$HOME/.dotfiles-atomic-state.json"

# Initialize atomic transaction
atomic_begin() {
    local transaction_id="${1:-$(date +%s)}"

    mkdir -p "$STAGING_DIR"
    mkdir -p "$BACKUP_DIR"

    cat > "$ATOMIC_STATE" <<EOF
{
  "transaction_id": "$transaction_id",
  "start_time": "$(date -Iseconds)",
  "status": "in_progress",
  "backups": [],
  "staged_configs": [],
  "installed_packages": []
}
EOF

    log_info "Atomic transaction started: $transaction_id"
}

# Backup file/directory before modification
atomic_backup() {
    local path="$1"
    local backup_id="$(date +%s)_$(basename "$path")"
    local backup_path="$BACKUP_DIR/$backup_id"

    if [[ ! -e "$path" ]]; then
        return 0
    fi

    log_info "Backing up: ${path/#$HOME/~}"

    if [[ -d "$path" ]]; then
        cp -a "$path" "$backup_path"
    else
        cp "$path" "$backup_path"
    fi

    # Record backup
    local temp_file
    temp_file=$(mktemp)

    jq --arg original "$path" --arg backup "$backup_path" \
        '.backups += [{"original": $original, "backup": $backup, "time": now | todate}]' \
        "$ATOMIC_STATE" > "$temp_file"

    mv "$temp_file" "$ATOMIC_STATE"

    log_success "✓ Backup created: $backup_id"
}

# Stage config for atomic link
atomic_stage_config() {
    local config="$1"
    local source="$DOTFILES_DIR/stow/$config"
    local staging="$STAGING_DIR/$config"

    if [[ ! -d "$source" ]]; then
        log_error "Config source not found: $config"
        return 1
    fi

    log_info "Staging config: $config"

    # Copy to staging
    mkdir -p "$(dirname "$staging")"
    cp -a "$source" "$staging"

    # Record staging
    local temp_file
    temp_file=$(mktemp)

    jq --arg config "$config" --arg staged "$staging" \
        '.staged_configs += [{"name": $config, "path": $staged}]' \
        "$ATOMIC_STATE" > "$temp_file"

    mv "$temp_file" "$ATOMIC_STATE"
}

# Atomically apply staged configs
atomic_commit_configs() {
    log_section "Committing Staged Configs"

    if [[ ! -f "$ATOMIC_STATE" ]]; then
        log_error "No atomic transaction in progress"
        return 1
    fi

    local configs_count
    configs_count=$(jq '.staged_configs | length' "$ATOMIC_STATE")

    if [[ $configs_count -eq 0 ]]; then
        log_info "No configs to commit"
        return 0
    fi

    log_info "Committing $configs_count configs..."

    # Backup existing configs
    source "$DOTFILES_DIR/lib/config.sh"
    local configs=()
    readarray -t configs < <(jq -r '.staged_configs[].name' "$ATOMIC_STATE")

    for config in "${configs[@]}"; do
        local target_dir=""

        case "$config" in
            shell)
                atomic_backup "$HOME/.zshrc"
                atomic_backup "$HOME/.zprofile"
                ;;
            *)
                atomic_backup "$HOME/.config/$config"
                ;;
        esac
    done

    # Apply all configs atomically
    cd "$DOTFILES_DIR/stow" || return 1

    for config in "${configs[@]}"; do
        log_info "Linking: $config"

        if ! stow --restow --verbose=1 "$config" -t "$HOME" 2>&1 | grep -v "^LINK:" | tee -a "${DOTFILES_LOG_FILE:-/dev/null}"; then
            log_error "Failed to link: $config"
            return 1
        fi

        log_success "✓ Linked: $config"
    done

    log_success "✓ All configs committed"
    return 0
}

# Commit atomic transaction
atomic_commit() {
    log_section "Committing Atomic Transaction"

    if [[ ! -f "$ATOMIC_STATE" ]]; then
        log_error "No atomic transaction in progress"
        return 1
    fi

    # Commit staged configs
    if ! atomic_commit_configs; then
        log_error "Config commit failed"
        return 1
    fi

    # Update state
    local temp_file
    temp_file=$(mktemp)

    jq '.status = "committed" | .end_time = (now | todate)' \
        "$ATOMIC_STATE" > "$temp_file"

    mv "$temp_file" "$ATOMIC_STATE"

    # Move atomic state to archive
    local archive_state="$BACKUP_DIR/atomic-state-$(date +%s).json"
    mv "$ATOMIC_STATE" "$archive_state"

    # Clean staging
    rm -rf "$STAGING_DIR"

    log_success "✓ Atomic transaction committed"
    log_info "State archived: ${archive_state/#$HOME/~}"

    return 0
}

# Rollback atomic transaction
atomic_rollback() {
    log_section "Rolling Back Atomic Transaction"

    if [[ ! -f "$ATOMIC_STATE" ]]; then
        log_error "No atomic transaction in progress"
        return 1
    fi

    log_warning "Rolling back changes..."

    # Restore backups
    local backups_count
    backups_count=$(jq '.backups | length' "$ATOMIC_STATE")

    if [[ $backups_count -gt 0 ]]; then
        log_info "Restoring $backups_count backups..."

        jq -r '.backups[] | "\(.backup)|\(.original)"' "$ATOMIC_STATE" | while IFS='|' read -r backup original; do
            if [[ -e "$backup" ]]; then
                log_info "Restoring: ${original/#$HOME/~}"

                # Remove current version
                rm -rf "$original"

                # Restore backup
                if [[ -d "$backup" ]]; then
                    cp -a "$backup" "$original"
                else
                    cp "$backup" "$original"
                fi

                log_success "✓ Restored: ${original/#$HOME/~}"
            fi
        done
    fi

    # Remove staged configs
    rm -rf "$STAGING_DIR"

    # Update state
    local temp_file
    temp_file=$(mktemp)

    jq '.status = "rolled_back" | .end_time = (now | todate)' \
        "$ATOMIC_STATE" > "$temp_file"

    mv "$temp_file" "$ATOMIC_STATE"

    # Archive state
    local archive_state="$BACKUP_DIR/atomic-state-rollback-$(date +%s).json"
    mv "$ATOMIC_STATE" "$archive_state"

    log_success "✓ Transaction rolled back"
    log_info "State archived: ${archive_state/#$HOME/~}"

    return 0
}

# Check if transaction is in progress
atomic_in_progress() {
    [[ -f "$ATOMIC_STATE" ]] && \
        [[ "$(jq -r '.status' "$ATOMIC_STATE" 2>/dev/null)" == "in_progress" ]]
}

# Show atomic transaction status
atomic_status() {
    if [[ ! -f "$ATOMIC_STATE" ]]; then
        log_info "No atomic transaction in progress"
        return
    fi

    log_section "Atomic Transaction Status"

    local transaction_id status start_time
    transaction_id=$(jq -r '.transaction_id' "$ATOMIC_STATE")
    status=$(jq -r '.status' "$ATOMIC_STATE")
    start_time=$(jq -r '.start_time' "$ATOMIC_STATE")

    show_info "Transaction ID" "$transaction_id"
    show_info "Status" "$status"
    show_info "Started" "$start_time"

    local backups_count configs_count packages_count
    backups_count=$(jq '.backups | length' "$ATOMIC_STATE")
    configs_count=$(jq '.staged_configs | length' "$ATOMIC_STATE")
    packages_count=$(jq '.installed_packages | length' "$ATOMIC_STATE")

    echo
    show_info "Backups Created" "$backups_count"
    show_info "Configs Staged" "$configs_count"
    show_info "Packages Installed" "$packages_count"
}

# Cleanup old backups (keep last N)
atomic_cleanup() {
    local keep_count="${1:-5}"

    log_section "Cleaning Up Atomic Backups"

    # Remove old snapshots from state management
    if [[ -d "$SNAPSHOT_DIR" ]]; then
        local snapshot_count
        snapshot_count=$(find "$SNAPSHOT_DIR" -type f -name "*_packages.txt" | wc -l)

        if [[ $snapshot_count -gt $keep_count ]]; then
            log_info "Removing old snapshots (keeping last $keep_count)..."

            find "$SNAPSHOT_DIR" -type f -name "*_packages.txt" -printf '%T+ %p\n' | \
                sort -r | tail -n +$((keep_count + 1)) | cut -d' ' -f2- | \
                while read -r file; do
                    local base="${file%_packages.txt}"
                    rm -f "${base}_packages.txt" "${base}_explicit.txt" "${base}_stow.txt"
                    log_info "Removed: $(basename "$base")"
                done
        fi
    fi

    # Remove old backup states
    if [[ -d "$BACKUP_DIR" ]]; then
        local backup_states
        backup_states=$(find "$BACKUP_DIR" -type f -name "atomic-state-*.json" | wc -l)

        if [[ $backup_states -gt $keep_count ]]; then
            log_info "Removing old atomic states (keeping last $keep_count)..."

            find "$BACKUP_DIR" -type f -name "atomic-state-*.json" -printf '%T+ %p\n' | \
                sort -r | tail -n +$((keep_count + 1)) | cut -d' ' -f2- | \
                xargs rm -f
        fi
    fi

    log_success "✓ Cleanup complete"
}
