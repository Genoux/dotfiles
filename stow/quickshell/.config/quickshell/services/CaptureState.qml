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
    // Countdown before the shutter, in seconds. Three values cycle on one
    // button rather than opening a picker; 0 is off.
    readonly property var delayChoices: [0, 3, 5]
    property int delaySeconds: 0
    // Runtime countdown state comes from the screenshot script after selection,
    // not from the button press: slurp may remain open for any length of time.
    property int countdownSeconds: 0
    property bool countdownVisible: false
    property var countdownScreen: null

    readonly property string latestPath: captures.length > 0 ? captures[0] : ""

    // One clock for the bar pill and the popover, so the two never disagree.
    // It restarts with the shell: the session's start time is not persisted.
    readonly property bool recording: Privacy.recording
    readonly property bool recordingPaused: Privacy.paused
    property int recordingSeconds: 0

    onRecordingChanged: {
        if (recording)
            recordingSeconds = 0;
    }

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

    function fileUri(path) {
        return "file://" + path.split("/").map(segment => encodeURIComponent(segment).replace(/'/g, "%27")).join("/");
    }

    function copy(path) {
        if (!path)
            return;

        if (isVideo(path)) {
            Quickshell.execDetached(["wl-copy", "--type", "text/uri-list", fileUri(path) + "\r\n"]);
        } else {
            Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", path]);
        }
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

    // FileManager1 rather than xdg-open on the folder: it opens the folder with
    // the file already selected, in whichever file manager owns the name.
    function reveal(path) {
        if (!path)
            return;

        Quickshell.execDetached([
            "gdbus", "call", "--session",
            "--dest", "org.freedesktop.FileManager1",
            "--object-path", "/org/freedesktop/FileManager1",
            "--method", "org.freedesktop.FileManager1.ShowItems",
            "['" + fileUri(path) + "']", ""
        ]);
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

    function cycleDelay() {
        delaySeconds = delayChoices[(delayChoices.indexOf(delaySeconds) + 1) % delayChoices.length];
    }

    function showCountdown(seconds) {
        const remaining = Math.max(0, Number(seconds));
        if (remaining === 0) {
            countdownFallback.stop();
            countdownSeconds = 0;
            countdownVisible = false;
            return;
        }

        countdownSeconds = remaining;
        countdownScreen = ShellActions.focusedScreen();
        countdownVisible = true;
        // Do not strand the OSD if the capture process is killed between ticks.
        countdownFallback.restart();
    }

    function shoot(mode) {
        Quickshell.execDetached([
            ShellActions.localBin + "system-screenshot",
            mode,
            "--widget-delay"
        ]);
    }

    function formatDuration(totalSeconds) {
        const pad = (value) => String(value).padStart(2, "0");
        const hours = Math.floor(totalSeconds / 3600);
        const clock = pad(Math.floor((totalSeconds % 3600) / 60)) + ":" + pad(totalSeconds % 60);
        return hours > 0 ? pad(hours) + ":" + clock : clock;
    }

    function runRecorder(args) {
        Quickshell.execDetached([ShellActions.localBin + "system-screenrecord"].concat(args));
    }

    function record(scope) {
        runRecorder(audioEnabled ? [scope, "audio"] : [scope]);
    }

    function togglePause() {
        runRecorder(["pause"]);
    }

    function stopRecording() {
        // Drops the live state at once; the script still has to finalise the
        // file, and the bar should not look like it is recording meanwhile.
        Privacy.stopping = true;
        runRecorder(["stop"]);
    }

    Timer {
        interval: 1000
        running: root.recording && !root.recordingPaused
        repeat: true
        onTriggered: root.recordingSeconds++
    }

    Timer {
        id: countdownFallback

        interval: 1400
        repeat: false
        onTriggered: {
            root.countdownSeconds = 0;
            root.countdownVisible = false;
        }
    }

}
