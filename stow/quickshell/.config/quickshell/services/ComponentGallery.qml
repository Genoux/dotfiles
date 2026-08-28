pragma Singleton

import Quickshell
import qs.config

// Development-only surface for inspecting the shared QML component library.
// It stays behind IPC so normal shell startup has no visible debug chrome.
Singleton {
    id: root

    property bool visible: false
    property var screen: null

    function openFor(targetScreen) {
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
