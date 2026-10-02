pragma Singleton

import Quickshell
import Quickshell.Hyprland
import qs.config

// Session actions, plus the switch between bar and island. The menu itself is
// a bar popover anchored to the power widget, or a page of the island; this
// singleton owns the entries and dispatch, and relays the keybind's toggle to
// whichever is on the focused screen.
Singleton {
    id: root

    signal toggleRequested(var targetScreen)

    readonly property var entries: [
        {
            label: "Lock",
            iconName: "system-lock-screen-symbolic",
            command: ["system-lock"],
        },
        {
            label: "Sleep",
            iconName: "system-suspend-symbolic",
            command: ["systemctl", "suspend"],
        },
        {
            label: "Reboot",
            iconName: "system-reboot-symbolic",
            command: ["systemctl", "reboot"],
        },
        {
            label: "Shutdown",
            iconName: "system-shutdown-symbolic",
            command: ["systemctl", "poweroff"],
        },
        {
            label: "Log Out",
            iconName: "system-log-out-symbolic",
            dispatch: "exit",
        },
        {
            label: ShellLayout.island ? "Bar" : "Island",
            iconName: "view-restore-symbolic",
            toggleLayout: true,
        },
    ]

    function activate(entry) {
        if (!entry)
            return

        if (entry.toggleLayout)
            ShellLayout.toggleIsland()
        else if (entry.dispatch)
            Hyprland.dispatch(entry.dispatch)
        else if (entry.command)
            Quickshell.execDetached(entry.command)
    }

    function toggleFor(targetScreen) {
        toggleRequested(targetScreen)
    }

    function toggle() {
        toggleFor(ShellActions.focusedScreen())
    }
}
