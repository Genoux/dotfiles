pragma Singleton

import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    property bool visible: false
    property string query: ""
    property var screen: null

    function openFor(targetScreen) {
        if (PowerMenu.visible)
            PowerMenu.close()

        screen = targetScreen
        query = ""
        visible = true
    }

    function close() {
        visible = false
    }

    function finalizeClose() {
        query = ""
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
