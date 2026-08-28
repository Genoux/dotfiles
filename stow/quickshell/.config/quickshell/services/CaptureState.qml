pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

// Post-capture state. The capture scripts own grim, slurp, and the recorder;
// they push events here over the `capture` IPC target. Recording state itself
// still comes from Privacy's watch on /tmp/screenrecord.state, which is the
// only answer that survives a shell restart — IPC has no replay.
Singleton {
    id: root

    readonly property var videoExtensions: ["mp4", "mkv", "webm", "mov"]
    readonly property int maxPreviews: 5

    // Newest first. Consecutive captures stack rather than replacing one
    // another; past the cap the oldest falls off the bottom.
    property var captures: []
    property bool previewVisible: false
    // The scripts reach us over IPC and carry no screen context, so the card
    // lands wherever the pointer is, like the launcher and power menu do.
    property var screen: null
    // Remembered rather than duplicated per scope: the record segment offers
    // two scopes with one toggle, not four entries.
    property bool audioEnabled: false

    readonly property string latestPath: captures.length > 0 ? captures[0] : ""

    function nameOf(path) {
        return String(path ?? "").split("/").pop();
    }

    function isVideo(path) {
        return videoExtensions.includes(nameOf(path).split(".").pop().toLowerCase());
    }

    function present(path) {
        const trimmed = String(path ?? "").trim();
        if (trimmed.length === 0)
            return;

        // Re-presenting a path already on the stack would show it twice.
        const kept = captures.filter((entry) => entry !== trimmed);
        captures = [trimmed].concat(kept).slice(0, maxPreviews);
        screen = ShellActions.focusedScreen();
        previewVisible = true;
    }

    function remove(path) {
        captures = captures.filter((entry) => entry !== path);
        if (captures.length === 0)
            previewVisible = false;
    }

    function dismiss() {
        captures = [];
        previewVisible = false;
    }

    function copy(path) {
        if (!path)
            return;

        Quickshell.execDetached(["sh", "-c", `wl-copy --type image/png < '${path}'`]);
    }

    function edit(path) {
        if (!path)
            return;

        Quickshell.execDetached(["satty", "--filename", path, "--output-filename", path]);
        remove(path);
    }

    function open(path) {
        if (!path)
            return;

        Quickshell.execDetached(["xdg-open", path]);
        remove(path);
    }

    function discard(path) {
        if (!path)
            return;

        Quickshell.execDetached(["rm", "-f", path]);
        remove(path);
    }

    function openFolder() {
        const directory = latestPath.length > 0
            ? latestPath.slice(0, latestPath.lastIndexOf("/"))
            : ShellActions.homePath + "/Pictures";
        Quickshell.execDetached(["xdg-open", directory]);
    }

    function shoot(mode) {
        Quickshell.execDetached([ShellActions.localBin + "system-screenshot", mode]);
    }

    function record(scope) {
        const command = [ShellActions.localBin + "system-screenrecord", scope];
        if (audioEnabled)
            command.push("audio");
        Quickshell.execDetached(command);
    }

}
