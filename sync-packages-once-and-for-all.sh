#!/bin/bash
# Comprehensive package sync - fixes everything once and for all

set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DOTFILES_DIR/install/helpers/all.sh"

echo "========================================"
echo "  COMPREHENSIVE PACKAGE SYNC"
echo "========================================"
echo
echo "This will:"
echo "  1. Install ALL packages from dotfiles"
echo "  2. Remove packages not in dotfiles"
echo "  3. Fix any conflicts automatically"
echo "  4. Get you to 100% sync"
echo
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled"
    exit 0
fi

# Source package functions
source "$DOTFILES_DIR/lib/package.sh"

echo
log_section "Step 1: Installing ALL packages from dotfiles"
echo

# This will install everything and handle conflicts
packages_install

echo
log_section "Step 2: Finding packages NOT in dotfiles"
echo

# Get all explicitly installed packages
installed_official=()
while IFS= read -r pkg; do
    installed_official+=("$pkg")
done < <(pacman -Qeq | grep -vf <(pacman -Qmq))

installed_aur=()
while IFS= read -r pkg; do
    installed_aur+=("$pkg")
done < <(pacman -Qmq)

# Read dotfiles packages
dotfiles_official=()
if [[ -f "$DOTFILES_DIR/packages.txt" ]]; then
    while IFS= read -r pkg; do
        [[ -n "$pkg" && ! "$pkg" =~ ^# ]] && dotfiles_official+=("$pkg")
    done < "$DOTFILES_DIR/packages.txt"
fi

dotfiles_aur=()
if [[ -f "$DOTFILES_DIR/aur-packages.txt" ]]; then
    while IFS= read -r pkg; do
        [[ -n "$pkg" && ! "$pkg" =~ ^# ]] && dotfiles_aur+=("$pkg")
    done < "$DOTFILES_DIR/aur-packages.txt"
fi

# Find extras
extra_official=()
for pkg in "${installed_official[@]}"; do
    if [[ ! " ${dotfiles_official[@]} " =~ " ${pkg} " ]]; then
        extra_official+=("$pkg")
    fi
done

extra_aur=()
for pkg in "${installed_aur[@]}"; do
    if [[ ! " ${dotfiles_aur[@]} " =~ " ${pkg} " ]]; then
        extra_aur+=("$pkg")
    fi
done

total_extra=$((${#extra_official[@]} + ${#extra_aur[@]}))

if [[ $total_extra -eq 0 ]]; then
    log_success "No extra packages found!"
else
    log_warning "Found $total_extra packages NOT in dotfiles:"
    echo

    if [[ ${#extra_official[@]} -gt 0 ]]; then
        log_info "Official packages (${#extra_official[@]}):"
        printf '  - %s\n' "${extra_official[@]}" | head -20
        [[ ${#extra_official[@]} -gt 20 ]] && echo "  ... and $((${#extra_official[@]} - 20)) more"
        echo
    fi

    if [[ ${#extra_aur[@]} -gt 0 ]]; then
        log_info "AUR packages (${#extra_aur[@]}):"
        printf '  - %s\n' "${extra_aur[@]}" | head -20
        [[ ${#extra_aur[@]} -gt 20 ]] && echo "  ... and $((${#extra_aur[@]} - 20)) more"
        echo
    fi

    echo
    echo "What do you want to do with these $total_extra packages?"
    echo "  1) Add them to dotfiles (keep installed)"
    echo "  2) Remove them from system"
    echo "  3) Skip (leave as-is)"
    echo
    read -p "Choice [1-3]: " -n 1 -r choice
    echo
    echo

    case $choice in
        1)
            log_info "Adding $total_extra packages to dotfiles..."
            echo

            for pkg in "${extra_official[@]}"; do
                echo "$pkg" >> "$DOTFILES_DIR/packages.txt"
            done
            for pkg in "${extra_aur[@]}"; do
                echo "$pkg" >> "$DOTFILES_DIR/aur-packages.txt"
            done

            sort -u "$DOTFILES_DIR/packages.txt" -o "$DOTFILES_DIR/packages.txt"
            sort -u "$DOTFILES_DIR/aur-packages.txt" -o "$DOTFILES_DIR/aur-packages.txt"

            log_success "Added $total_extra packages to dotfiles"
            ;;
        2)
            log_info "Checking which packages can be safely removed..."
            echo

            all_extra=("${extra_official[@]}" "${extra_aur[@]}")
            safe_to_remove=()
            blocked_packages=()

            for pkg in "${all_extra[@]}"; do
                required_by=$(pacman -Qi "$pkg" 2>/dev/null | grep "Required By" | cut -d: -f2 | xargs)

                if [[ -z "$required_by" || "$required_by" == "None" ]]; then
                    safe_to_remove+=("$pkg")
                else
                    blocked_packages+=("$pkg (required by: $required_by)")
                fi
            done

            if [[ ${#blocked_packages[@]} -gt 0 ]]; then
                log_warning "Cannot remove these (required by other packages):"
                printf '  - %s\n' "${blocked_packages[@]}"
                echo
            fi

            if [[ ${#safe_to_remove[@]} -gt 0 ]]; then
                log_info "Removing ${#safe_to_remove[@]} packages:"
                printf '  - %s\n' "${safe_to_remove[@]}"
                echo

                sudo pacman -Rns --noconfirm "${safe_to_remove[@]}"
                log_success "Removed ${#safe_to_remove[@]} packages"
            else
                log_info "No packages can be safely removed (all are dependencies)"
            fi
            ;;
        3)
            log_info "Skipping extra packages cleanup"
            ;;
        *)
            log_warning "Invalid choice, skipping"
            ;;
    esac
fi

echo
log_section "Final Status"
echo

# Show final counts
pkg_count=$(grep -cvE '^#|^$' "$DOTFILES_DIR/packages.txt" 2>/dev/null || echo 0)
aur_count=$(grep -cvE '^#|^$' "$DOTFILES_DIR/aur-packages.txt" 2>/dev/null || echo 0)
installed_count=$(pacman -Qe | wc -l)

show_info "Official packages in dotfiles" "$pkg_count"
show_info "AUR packages in dotfiles" "$aur_count"
show_info "Total in dotfiles" "$((pkg_count + aur_count))"
echo
show_info "Total installed" "$installed_count"
echo

if [[ $((pkg_count + aur_count)) -eq $installed_count ]]; then
    log_success "✓ PERFECTLY SYNCED! Dotfiles = System"
else
    diff=$((installed_count - pkg_count - aur_count))
    if [[ $diff -gt 0 ]]; then
        log_warning "$diff packages installed but not in dotfiles (likely dependencies)"
    else
        log_warning "$((-diff)) packages in dotfiles but not installed"
    fi
fi

echo
log_success "Sync complete!"
