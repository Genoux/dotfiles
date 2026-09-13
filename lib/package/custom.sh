#!/bin/bash
# Custom package builds: GitHub repos with a PKGBUILD at their root, built
# with makepkg -si. Runs last in the install order — these are the packages
# most likely to need a fresh toolchain or network access that just got
# installed by the official/AUR phases.

CUSTOM_PACKAGES_FILE="$DOTFILES_DIR/packages/custom.package"
CUSTOM_PACKAGE_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/custom"

read_custom_packages() {
    local -n repos_ref=$1

    repos_ref=()
    [[ -f "$CUSTOM_PACKAGES_FILE" ]] || return 0

    while IFS= read -r repo; do
        [[ -z "$repo" ]] && continue
        [[ "$repo" =~ ^#.*$ ]] && continue
        repos_ref+=("$repo")
    done < "$CUSTOM_PACKAGES_FILE"
}

# Ensure `gh` is authenticated, prompting an interactive login when it is
# not. Returns 1 only when the user declines/skips login — the caller treats
# that as "skip the phase", not a hard failure.
_ensure_github_auth() {
    # github-cli is tracked in packages/arch.package, installed by the
    # official phase's single `pacman -Syu` — verify only here.
    if ! command -v gh &>/dev/null; then
        log_error "github-cli not installed. Run: dotfiles packages install"
        return 1
    fi

    if gh auth status &>/dev/null; then
        return 0
    fi

    if [[ "${FULL_INSTALL:-false}" == "true" || ! -t 0 ]]; then
        log_warning "Custom apps need GitHub login. Later: gh auth login; dotfiles packages custom"
        return 1
    fi

    log_info "GitHub authentication required for custom package builds"
    if ! gh auth login --hostname github.com --git-protocol https --web; then
        return 1
    fi
    gh auth setup-git

    gh auth status &>/dev/null
}

_build_custom_package() {
    local repo="$1"
    local repo_dir="$CUSTOM_PACKAGE_CACHE/$repo"

    mkdir -p "$(dirname "$repo_dir")"

    if [[ -d "$repo_dir/.git" ]]; then
        log_info "Updating $repo..."
        if ! git -C "$repo_dir" pull --ff-only; then
            log_error "Failed to update $repo"
            return 1
        fi
    else
        log_info "Cloning $repo..."
        if ! gh repo clone "$repo" "$repo_dir"; then
            log_error "Failed to clone $repo"
            return 1
        fi
    fi

    if [[ ! -f "$repo_dir/PKGBUILD" ]]; then
        log_error "$repo has no PKGBUILD at its root"
        return 1
    fi

    # BUILDDIR/PKGDEST outside the clone: makepkg's default src/ would land
    # inside repos whose own source tree is src/ (Genoux/flow), and build
    # output in the clone would dirty it for the next `git pull --ff-only`.
    if ! (cd "$repo_dir" && BUILDDIR="$CUSTOM_PACKAGE_CACHE/.build" PKGDEST="$CUSTOM_PACKAGE_CACHE/.pkg" \
        makepkg -si --needed --noconfirm); then
        log_error "Failed to build $repo"
        return 1
    fi

    log_success "✓ Built $repo"
    return 0
}

# Build every repo in packages/custom.package. Returns 0 with a "skipped"
# status message (not a failure) when there is nothing to build or the user
# declines GitHub authentication; returns 1 only on an actual build failure.
packages_custom() {
    log_section "Custom Package Builds"

    local repos=()
    read_custom_packages repos

    if [[ ${#repos[@]} -eq 0 ]]; then
        log_info "No custom packages declared in packages/custom.package — skipping"
        return 0
    fi

    if ! _ensure_github_auth; then
        log_warning "GitHub authentication skipped — custom package builds skipped"
        return 0
    fi

    local failed=()
    for repo in "${repos[@]}"; do
        _build_custom_package "$repo" || failed+=("$repo")
    done

    if [[ ${#failed[@]} -gt 0 ]]; then
        log_error "Failed to build ${#failed[@]} custom package(s):"
        printf '  ✗ %s\n' "${failed[@]}"
        return 1
    fi

    log_success "✓ All custom packages built"
    return 0
}
