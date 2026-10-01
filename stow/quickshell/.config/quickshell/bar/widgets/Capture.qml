import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import qs
import qs.components
import qs.config
import qs.services

Button {
    id: root

    required property var screen
    required property var barWindow
    property bool collapsing: false
    property bool hoverArmed: false
    property color displayForeground: Colors.base05
    readonly property bool recording: Privacy.recording
    readonly property bool paused: Privacy.paused
    readonly property bool visualRecording: recording || collapsing
    // Held open while paused: the frozen timer and resume button are the only
    // sign the session is still live.
    readonly property bool expanded: recording && (hoverArmed || paused)
    readonly property color trailForeground: Colors.base05
    property color recordingColor: StyleRecording.fill
    property int elapsedSeconds: 0

    function recorderCommand(extraArgs) {
        return [ShellActions.localBin + "system-screenrecord"].concat(extraArgs ?? []);
    }

    function runRecorder(extraArgs) {
        Quickshell.execDetached(recorderCommand(extraArgs));
    }

    function pad2(value) {
        return value < 10 ? "0" + value : "" + value;
    }

    function formatElapsed(totalSeconds) {
        const hours = Math.floor(totalSeconds / 3600);
        const minutes = Math.floor((totalSeconds % 3600) / 60);
        const seconds = totalSeconds % 60;
        if (hours > 0)
            return pad2(hours) + ":" + pad2(minutes) + ":" + pad2(seconds);

        return pad2(minutes) + ":" + pad2(seconds);
    }

    function showPauseState() {
        pulseAnimation.stop();
        if (paused) {
            recordingColor = StyleRecording.paused;
            return;
        }
        recordingColor = StyleRecording.fill;
        pulseAnimation.start();
    }

    function hits(item, mouse) {
        return root.trailReveal > 0 && item.contains(item.mapFromItem(root, mouse.x, mouse.y));
    }

    function beginRecording() {
        hideAnimation.stop();
        collapsing = false;
        elapsedSeconds = 0;
        elapsedTimer.restart();
        displayForeground = trailForeground;
        showPauseState();
        hoverArmed = false;
        revealTimer.stop();
        if (root.hovered)
            revealTimer.restart();
    }

    function endRecording() {
        if (collapsing && hideAnimation.running)
            return;
        collapsing = true;
        hoverArmed = false;
        revealTimer.stop();
        elapsedSeconds = 0;
        elapsedTimer.stop();
        pulseAnimation.stop();
        hideAnimation.restart();
    }

    iconSource: root.visualRecording
        ? IconRegistry.captureIcon("recording")
        : IconRegistry.captureIcon("idle")
    foreground: displayForeground
    background: visualRecording ? recordingColor : StyleTokens.transparent
    hoverBackground: StyleTokens.alphaLight
    interactive: true
    active: recordPopover.open
    animateColor: false
    manageHoverColor: !visualRecording
    clipContent: true
    trailGap: StyleTokens.space2
    trailPaddingRight: StyleTokens.space3
    trailWidth: trailRow.implicitWidth
    // The base Button's MouseArea sits above its trail, so the trail controls
    // are hit-tested here rather than given MouseAreas of their own. Anywhere
    // else on the pill stops, as it did before pause existed.
    onClicked: (mouse) => {
        if (root.recording && root.hits(pauseIcon, mouse)) {
            runRecorder(["pause"]);
            return;
        }
        if (root.recording || root.collapsing || Privacy.rawRecording) {
            Privacy.stopping = true;
            runRecorder(["stop"]);
            return;
        }
        recordPopover.toggle();
    }
    onRecordingChanged: {
        if (root.recording)
            root.beginRecording();
        else
            root.endRecording();
    }
    onPausedChanged: {
        if (root.recording)
            root.showPauseState();
    }
    onHoveredChanged: {
        if (hovered && recording) {
            revealTimer.restart();
            return;
        }
        revealTimer.stop();
        hoverArmed = false;
    }
    Component.onCompleted: {
        if (root.recording)
            root.beginRecording();
    }

    Row {
        id: trailRow

        anchors.verticalCenter: parent.verticalCenter
        spacing: StyleTokens.space2
        opacity: root.trailReveal

        Text {
            text: root.formatElapsed(root.elapsedSeconds)
            color: root.trailForeground
            font.family: StyleTokens.fontMono
            font.pixelSize: StyleBar.labelFontSize
            height: root.labelLineHeight
            verticalAlignment: Text.AlignVCenter
        }

        ThemedIcon {
            id: pauseIcon

            anchors.verticalCenter: parent.verticalCenter
            source: IconRegistry.captureIcon(root.paused ? "resume" : "pause")
            tint: root.trailForeground
            size: root.iconSize
        }

        ThemedIcon {
            anchors.verticalCenter: parent.verticalCenter
            source: IconRegistry.captureIcon("stop")
            tint: root.trailForeground
            size: root.iconSize
        }
    }

    BarPopover {
        id: recordPopover

        barWindow: root.barWindow
        anchorItem: root

        CapturePopover {
            active: recordPopover.open
            onDismissRequested: recordPopover.dismissNow()
        }
    }

    Timer {
        id: revealTimer

        interval: StyleTokens.motionHoverDelay
        onTriggered: root.hoverArmed = true
    }

    Binding {
        target: root
        property: "trailReveal"
        value: root.expanded ? 1 : 0
        when: !hideAnimation.running
    }

    Behavior on trailReveal {
        enabled: !hideAnimation.running

        NumberAnimation {
            duration: StyleRecording.expandDuration
            easing.type: StyleTokens.easeStandard
        }
    }

    ParallelAnimation {
        id: hideAnimation

        NumberAnimation {
            target: root
            property: "trailReveal"
            to: 0
            duration: StyleRecording.expandDuration
            easing.type: StyleTokens.easeStandard
        }

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: Qt.rgba(StyleRecording.fill.r, StyleRecording.fill.g, StyleRecording.fill.b, 0)
            duration: StyleRecording.expandDuration
            easing.type: StyleTokens.easeFade
        }

        ColorAnimation {
            target: root
            property: "displayForeground"
            to: Colors.base05
            duration: StyleRecording.expandDuration
            easing.type: StyleTokens.easeFade
        }

        onFinished: {
            root.collapsing = false;
            root.recordingColor = StyleRecording.fill;
        }
    }

    SequentialAnimation {
        id: pulseAnimation

        loops: Animation.Infinite

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: StyleRecording.pulse
            duration: StyleRecording.pulseDuration
            easing.type: StyleTokens.easePulse
        }

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: StyleRecording.fill
            duration: StyleRecording.pulseDuration
            easing.type: StyleTokens.easePulse
        }

    }

    Timer {
        id: elapsedTimer

        interval: 1000
        running: root.recording && !root.paused
        repeat: true
        triggeredOnStart: false
        onTriggered: root.elapsedSeconds++
    }

}
