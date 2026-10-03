pragma Singleton

import Quickshell
import Quickshell.Hyprland
import qs.config

Singleton {
    id: root

    property bool visible: false
    property string query: ""
    property var screen: null
    // History reorders its model, so a launch is recorded only once the list
    // that launched it is out of sight.
    property string pendingHistoryId: ""

    function launch(entry) {
        if (!entry)
            return;

        pendingHistoryId = entry.id;
        if (entry.runInTerminal)
            launchInTerminal(entry);
        else
            // app2unit rather than entry.execute(): it puts the app in its own
            // app.slice scope, so systemd-oomd can reclaim it individually
            // instead of it inheriting the compositor's session-5.scope.
            Quickshell.execDetached(["app2unit", "--", `${entry.id}.desktop`]);
    }

    // TUI apps get one window each: a second launch raises the existing one
    // instead of spawning a duplicate. cliamp writes an IPC socket but only
    // warns on a second instance, so nothing else enforces this.
    function launchInTerminal(entry) {
        const existing = Hyprland.toplevels.values.find(w => w.wayland?.appId === entry.id || w.lastIpcObject?.class === entry.id);
        if (existing?.wayland)
            existing.wayland.activate();
        else
            Quickshell.execDetached(["app2unit", "--", "kitty", "--class", entry.id, "-e", ...entry.command]);
    }

    function recordPendingLaunch() {
        if (!pendingHistoryId)
            return;

        LauncherHistory.record(DesktopEntries.byId(pendingHistoryId));
        pendingHistoryId = "";
    }

    function openFor(targetScreen) {
        PopoverCoordinator.closeCurrent()

        screen = targetScreen
        query = ""
        visible = true
    }

    function close() {
        visible = false
    }

    function finalizeClose() {
        if (!visible)
            query = ""
    }

    function toggleFor(targetScreen) {
        if (!ShellLayout.wide) {
            ShellLayout.togglePage("launcher", targetScreen);
            return;
        }

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
