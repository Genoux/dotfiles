import { GLib } from "astal"
import { showConfirmation } from "./components/ConfirmationOverlay"

// =============================================================================
// System Control Service - Pure Logic Only
// =============================================================================

function executeSystemCommand(command: string, description: string) {
    try {
        console.log(`Executing ${description}...`)
        GLib.spawn_command_line_async(command)
    } catch (error) {
        console.error(`Failed to execute ${description}:`, error)
    }
}

function handleShutdown() {
    showConfirmation({
        title: "Shutdown System",
        message: "Are you sure you want to shutdown?",
        onConfirm: () => executeSystemCommand("systemctl poweroff", "shutdown system"),
        onCancel: () => console.log("Shutdown cancelled")
    })
}

function handleSleep() {
    showConfirmation({
        title: "Suspend System", 
        message: "Put the system to sleep?",
        onConfirm: () => executeSystemCommand("systemctl suspend", "suspend system"),
        onCancel: () => console.log("Sleep cancelled")
    })
}

function handleLock() {
    executeSystemCommand("hyprlock", "lock screen")
}

// System actions configuration
export const systemActions = [
    {
        icon: "system-lock-screen-symbolic",
        tooltip: "Lock Screen", 
        action: handleLock,
        className: "lock-btn"
    },
    {
        icon: "system-suspend-symbolic",
        tooltip: "Sleep",
        action: handleSleep,
        className: "sleep-btn"
    },
    {
        icon: "system-shutdown-symbolic",
        tooltip: "Shutdown",
        action: handleShutdown,
        className: "shutdown-btn"
    }
] 