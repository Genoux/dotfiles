pragma Singleton

import Quickshell
import qs.config

Singleton {
    id: root

    property bool visible: false
    property var screen: null

    readonly property var entries: [
        {
            id: "lock",
            label: "Lock",
            icon: "system-lock-screen-symbolic",
            command: ["system-lock"],
        },
        {
            id: "sleep",
            label: "Sleep",
            icon: "system-suspend-symbolic",
            command: ["systemctl", "suspend"],
        },
        {
            id: "reboot",
            label: "Reboot",
            icon: "system-reboot-symbolic",
            command: ["systemctl", "reboot"],
        },
        {
            id: "shutdown",
            label: "Shutdown",
            icon: "system-shutdown-symbolic",
            command: ["systemctl", "poweroff"],
        },
        {
            id: "logout",
            label: "Log Out",
            icon: "system-log-out-symbolic",
            dispatch: "exit",
        },
    ]

    function openFor(targetScreen) {
        if (Launcher.visible)
            Launcher.close()

        screen = targetScreen
        visible = true
    }

    function close() {
        visible = false
    }

    function toggleFor(targetScreen) {
        if (visible && screen === targetScreen) {
            close()
            return
        }

        openFor(targetScreen)
    }

    function toggle() {
        toggleFor(ShellActions.focusedScreen())
    }
}
