pragma Singleton

import Quickshell
import qs.config

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

    function toggle() {
        toggleFor(ShellActions.focusedScreen())
    }
}
