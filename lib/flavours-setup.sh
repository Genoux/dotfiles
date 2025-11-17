#!/bin/bash
# Flavours setup helper - ensures flavours is installed and templates are downloaded

DOTFILES_DIR="$(cd "$(dirname "$(dirname "${BASH_SOURCE[0]}")")" && pwd)"

# Source helpers if not already loaded
if [[ -z "${DOTFILES_HELPERS_LOADED:-}" ]]; then
    source "$DOTFILES_DIR/install/helpers/all.sh"
    export DOTFILES_HELPERS_LOADED=true
fi

# Ensure flavours is installed
ensure_flavours_installed() {
    if command -v flavours &>/dev/null; then
        log_success "flavours is already installed"
        return 0
    fi

    log_info "Installing flavours via cargo..."

    # Check if cargo is installed
    if ! command -v cargo &>/dev/null; then
        log_error "cargo not found - please install rust/cargo first"
        log_info "Install with: sudo pacman -S rust"
        return 1
    fi

    # Install flavours
    if cargo install --locked flavours; then
        log_success "flavours installed successfully"
        log_info "Note: ~/.cargo/bin should be in your PATH"
        return 0
    else
        log_error "Failed to install flavours"
        return 1
    fi
}

# Download required base16 templates
download_templates() {
    local templates_dir="$HOME/.local/share/flavours/base16/templates"

    log_info "Checking flavours templates..."

    # Flavours should exist now
    local flavours_cmd="${FLAVOURS_COMMAND:-flavours}"
    if ! command -v "$flavours_cmd" &>/dev/null; then
        flavours_cmd="$HOME/.cargo/bin/flavours"
    fi

    # Just the templates we need (others don't have official templates)
    local needed_templates=(
        "kitty|https://github.com/kdrag0n/base16-kitty"
        "mako|https://github.com/Eluminae/base16-mako"
    )

    mkdir -p "$templates_dir"

    for template_info in "${needed_templates[@]}"; do
        local name="${template_info%%|*}"
        local url="${template_info##*|}"

        if [[ -d "$templates_dir/$name" ]]; then
            log_info "  ✓ $name template already exists"
        else
            log_info "  Downloading $name template..."
            if git clone --depth=1 --quiet "$url" "$templates_dir/$name" 2>/dev/null; then
                log_success "  ✓ Downloaded $name template"
            else
                log_warning "  ⊘ Failed to download $name template"
            fi
        fi
    done
}

# Main setup function
flavours_setup() {
    log_section "Flavours Setup"

    # Install flavours
    ensure_flavours_installed || return 1

    # Download templates
    download_templates

    log_success "Flavours setup complete!"
    return 0
}

# If run directly, execute setup
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    flavours_setup
fi
