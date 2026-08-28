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
    readonly property bool visualRecording: recording || collapsing
    readonly property bool expanded: hoverArmed && recording
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

    function beginRecording() {
        hideAnimation.stop();
        collapsing = false;
        elapsedSeconds = 0;
        elapsedTimer.restart();
        pulseAnimation.stop();
        recordingColor = StyleRecording.fill;
        displayForeground = trailForeground;
        pulseAnimation.start();
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
    trailWidth: durationLabel.implicitWidth
    onClicked: (mouse) => {
        if (root.recording || root.collapsing || Privacy.rawRecording) {
            Privacy.stopping = true;
            runRecorder([]);
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

    Text {
        id: durationLabel

        anchors.verticalCenter: parent.verticalCenter
        text: root.formatElapsed(root.elapsedSeconds)
        color: root.trailForeground
        opacity: root.trailReveal
        font.family: StyleTokens.fontMono
        font.pixelSize: StyleBar.labelFontSize
        height: root.labelLineHeight
        verticalAlignment: Text.AlignVCenter
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

        interval: StyleMedia.controlsHoverDelay
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
            duration: StyleMedia.controlsRevealDuration
            easing.type: StyleTokens.easeStandard
        }
    }

    ParallelAnimation {
        id: hideAnimation

        NumberAnimation {
            target: root
            property: "trailReveal"
            to: 0
            duration: StyleMedia.controlsRevealDuration
            easing.type: StyleTokens.easeStandard
        }

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: Qt.rgba(StyleRecording.fill.r, StyleRecording.fill.g, StyleRecording.fill.b, 0)
            duration: StyleMedia.controlsRevealDuration
            easing.type: StyleTokens.easeStandard
        }

        ColorAnimation {
            target: root
            property: "displayForeground"
            to: Colors.base05
            duration: StyleMedia.controlsRevealDuration
            easing.type: StyleTokens.easeStandard
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
            easing.type: Easing.InOutSine
        }

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: StyleRecording.fill
            duration: StyleRecording.pulseDuration
            easing.type: Easing.InOutSine
        }

    }

    Timer {
        id: elapsedTimer

        interval: 1000
        running: root.recording
        repeat: true
        triggeredOnStart: false
        onTriggered: root.elapsedSeconds++
    }

}
