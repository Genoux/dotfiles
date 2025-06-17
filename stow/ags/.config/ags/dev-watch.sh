#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AGS_DIR="$(dirname "$0")"
DEBOUNCE_TIME=0.3
DEBOUNCE_PID_FILE="/tmp/ags-debounce.pid"
AGS_LOG_FILE="/tmp/ags-dev.log"

# Function to print colored output
log() {
    echo -e "${BLUE}[$(date '+%H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ERROR:${NC} $1"
}

success() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] SUCCESS:${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] WARNING:${NC} $1"
}

# Show usage
show_usage() {
    echo -e "${BLUE}⚡ AGS Development Watcher${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -l, --logs     Show AGS logs in real-time (tail -f)"
    echo "  -s, --silent   Run silently (default behavior)"
    echo "  -v, --verbose  Show AGS logs mixed with watcher output"
    echo "  -h, --help     Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Run silently (logs saved to $AGS_LOG_FILE)"
    echo "  $0 --logs       # Show AGS logs in real-time"
    echo "  $0 --verbose    # Show everything mixed together"
    echo ""
    echo "To view logs in another terminal:"
    echo "  tail -f $AGS_LOG_FILE"
}

# Parse command line arguments
SHOW_LOGS=false
VERBOSE=false
SILENT=true

while [[ $# -gt 0 ]]; do
    case $1 in
        -l|--logs)
            SHOW_LOGS=true
            SILENT=false
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            SILENT=false
            shift
            ;;
        -s|--silent)
            SILENT=true
            SHOW_LOGS=false
            VERBOSE=false
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Simple restart function
restart_ags() {
    log "Restarting AGS..."
    
    # Quit AGS gracefully
    ags quit >/dev/null 2>&1
    
    # Wait a moment
    sleep 0.2
    
    # Start AGS again
    cd "$AGS_DIR"
    
    if [ "$VERBOSE" = true ]; then
        # Show logs mixed with watcher output
        ags run . &
    elif [ "$SHOW_LOGS" = true ]; then
        # Log to file and show with tail
        ags run . > "$AGS_LOG_FILE" 2>&1 &
    else
        # Silent mode - log to file only
        ags run . > "$AGS_LOG_FILE" 2>&1 &
    fi
    
    # Quick check if it started
    sleep 0.2
    if pgrep -f "ags" >/dev/null 2>&1; then
        success "AGS restarted"
    else
        error "AGS failed to restart"
    fi
}

# Debounced restart
debounced_restart() {
    local lock_file="/tmp/ags-restart.lock"
    
    # Check if restart is already in progress
    if [ -f "$lock_file" ]; then
        return 0
    fi
    
    # Kill existing debounce
    if [ -f "$DEBOUNCE_PID_FILE" ]; then
        kill $(cat "$DEBOUNCE_PID_FILE" 2>/dev/null) 2>/dev/null
        rm -f "$DEBOUNCE_PID_FILE"
    fi
    
    # Start new debounce
    (
        echo $$ > "$DEBOUNCE_PID_FILE"
        touch "$lock_file"
        sleep $DEBOUNCE_TIME
        rm -f "$DEBOUNCE_PID_FILE" "$lock_file"
        restart_ags
    ) &
}

# Dependency checks
if ! command -v ags >/dev/null; then
    error "AGS not found in PATH"
    exit 1
fi

if ! command -v inotifywait >/dev/null; then
    error "inotifywait not found. Install inotify-tools package"
    exit 1
fi

# Directory check
if [ ! -d "$AGS_DIR" ]; then
    error "AGS directory not found: $AGS_DIR"
    exit 1
fi

# Cleanup on exit
cleanup_on_exit() {
    log "Cleaning up..."
    ags quit >/dev/null 2>&1
    rm -f "$DEBOUNCE_PID_FILE"
    rm -f "/tmp/ags-restart.lock"
    if [ "$SHOW_LOGS" = true ]; then
        # Kill the tail process if it exists
        pkill -f "tail -f $AGS_LOG_FILE" 2>/dev/null
    fi
    exit 0
}

trap cleanup_on_exit INT TERM

echo -e "${BLUE}⚡ AGS Development Watcher${NC}"
echo -e "${BLUE}=========================${NC}"
log "Watching: $AGS_DIR"
log "Debounce: ${DEBOUNCE_TIME}s"
log "AGS logs: $AGS_LOG_FILE"

if [ "$SHOW_LOGS" = true ]; then
    log "Log viewing: Real-time tail"
elif [ "$VERBOSE" = true ]; then
    log "Log viewing: Mixed output"
else
    log "Log viewing: Silent (use 'tail -f $AGS_LOG_FILE' to view)"
fi

# Initial start
log "Starting AGS..."
cd "$AGS_DIR"
ags quit >/dev/null 2>&1  # Clean stop
sleep 0.2

# Initialize log file
echo "=== AGS Development Log - $(date) ===" > "$AGS_LOG_FILE"

if [ "$VERBOSE" = true ]; then
    ags run . &
elif [ "$SHOW_LOGS" = true ]; then
    ags run . > "$AGS_LOG_FILE" 2>&1 &
    # Start tailing logs in background
    (sleep 1; tail -f "$AGS_LOG_FILE" &) 
else
    ags run . > "$AGS_LOG_FILE" 2>&1 &
fi

sleep 0.3
if pgrep -f "ags" >/dev/null 2>&1; then
    success "AGS started successfully"
    if [ "$SILENT" = true ]; then
        echo -e "${YELLOW}💡 Tip: Use 'tail -f $AGS_LOG_FILE' in another terminal to view AGS logs${NC}"
    fi
else
    error "AGS failed to start"
    exit 1
fi

# If showing logs, start the tail process
if [ "$SHOW_LOGS" = true ]; then
    echo -e "${BLUE}📋 AGS Logs:${NC}"
    echo -e "${BLUE}============${NC}"
    tail -f "$AGS_LOG_FILE" &
    TAIL_PID=$!
fi

# Watch for changes - simple and reliable
log "👀 Watching for changes..."

while true; do
    log "Starting file watcher..."
    
    inotifywait -m -r -e modify,create,delete,move "$AGS_DIR" 2>/dev/null | while read -r directory events filename; do
        
        # Skip directories we don't care about
        case "$directory" in
            *node_modules*|*.git*|*dist*|*build*) continue ;;
        esac
        
        # Only watch specific file types
        case "$filename" in
            *.ts|*.tsx|*.js|*.jsx|*.scss|*.css|*.json)
                # Skip hidden files and temp files
                case "$filename" in
                    .*|*~|*.tmp|*.swp) continue ;;
                esac
                
                warn "Changed: $filename"
                debounced_restart
                ;;
        esac
    done
    
    # If we get here, inotifywait exited
    error "File watcher exited, restarting in 2 seconds..."
    sleep 2
done