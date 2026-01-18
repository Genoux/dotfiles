#!/bin/bash
# Source all helper modules

HELPERS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$(dirname "$(dirname "$(dirname "${BASH_SOURCE[0]}")")")" && pwd)"

source "$HELPERS_DIR/presentation.sh"
source "$HELPERS_DIR/errors.sh"
source "$HELPERS_DIR/hardware.sh"
source "$HELPERS_DIR/logging.sh"
source "$HELPERS_DIR/progress.sh"
source "$DOTFILES_DIR/lib/common.sh"

