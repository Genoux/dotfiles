pragma Singleton

import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    property bool visible: false
    property var screen: null

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

    function focusedScreen() {
        const monitor = Hyprland.focusedMonitor
        if (!monitor)
            return Quickshell.screens[0] ?? null

        return Quickshell.screens.find((candidate) => {
            const hyprMonitor = Hyprland.monitorFor(candidate)
            return hyprMonitor === monitor || hyprMonitor?.name === monitor?.name
        }) ?? Quickshell.screens[0] ?? null
    }

    function toggle() {
        toggleFor(focusedScreen())
    }
}
