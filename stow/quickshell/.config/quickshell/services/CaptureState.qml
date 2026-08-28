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

    property string latestPath: ""
    property bool previewVisible: false
    // The scripts reach us over IPC and carry no screen context, so the card
    // lands wherever the pointer is, like the launcher and power menu do.
    property var screen: null
    // Remembered rather than duplicated per scope: the record segment offers
    // two scopes with one toggle, not four entries.
    property bool audioEnabled: false

    readonly property string latestName: latestPath.split("/").pop()
    readonly property bool latestIsVideo: videoExtensions.includes(latestName.split(".").pop().toLowerCase())
    readonly property string posterPath: `/tmp/qs-capture-poster-${latestName}.jpg`
    // A video needs a frame extracted before it can be shown; an image is its
    // own thumbnail.
    readonly property string thumbnailSource: {
        if (latestPath.length === 0)
            return "";
        if (!latestIsVideo)
            return `file://${latestPath}`;
        return posterReady ? `file://${posterPath}` : "";
    }

    property bool posterReady: false

    function present(path) {
        const trimmed = String(path ?? "").trim();
        if (trimmed.length === 0)
            return;

        posterReady = false;
        latestPath = trimmed;
        screen = ShellActions.focusedScreen();
        previewVisible = true;

        if (latestIsVideo)
            posterProcess.running = true;
    }

    function dismiss() {
        previewVisible = false;
    }

    function copyLatest() {
        if (latestPath.length === 0)
            return;

        copyProcess.running = true;
    }

    function editLatest() {
        if (latestPath.length === 0)
            return;

        Quickshell.execDetached(["satty", "--filename", latestPath, "--output-filename", latestPath]);
        dismiss();
    }

    function openLatest() {
        if (latestPath.length === 0)
            return;

        Quickshell.execDetached(["xdg-open", latestPath]);
        dismiss();
    }

    function discardLatest() {
        if (latestPath.length === 0)
            return;

        Quickshell.execDetached(["rm", "-f", latestPath]);
        latestPath = "";
        dismiss();
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

    Process {
        id: copyProcess

        command: ["sh", "-c", `wl-copy --type image/png < '${root.latestPath}'`]
    }

    Process {
        id: posterProcess

        command: [
            "ffmpeg", "-y", "-i", root.latestPath,
            "-vframes", "1",
            "-vf", `scale=${StyleCapture.posterWidth}:-1`,
            root.posterPath
        ]

        onExited: (code) => root.posterReady = code === 0
    }
}
