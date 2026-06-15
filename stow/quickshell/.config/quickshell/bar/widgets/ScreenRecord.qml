import Quickshell
import QtQuick
import qs
import qs.config
import qs.components
import qs.services

Button {
    id: root

    readonly property bool recording: Privacy.screenrecord
    readonly property bool expanded: root.hovered && recording
    readonly property color trailForeground: "#ffffff"
    readonly property color iconForeground: !recording
        ? Colors.base05
        : mixColor(recordingColor, trailForeground, trailReveal)
    readonly property color backgroundFill: !recording
        ? (root.hovered ? StyleTokens.alphaLight : StyleTokens.transparent)
        : Qt.rgba(recordingColor.r, recordingColor.g, recordingColor.b, recordingColor.a * trailReveal)

    iconName: "media-record-symbolic"
    foreground: iconForeground
    background: backgroundFill
    interactive: true
    animateColor: false
    manageHoverColor: false
    clipContent: true
    trailGap: 2
    trailWidth: durationLabel.implicitWidth

    property color recordingColor: StyleRecording.fill
    property int elapsedSeconds: 0

    onClicked: ShellActions.run(Privacy.screenrecord ? ["system-screenrecord"] : ["system-screenrecord", "region"])

    function mixColor(from, to, amount) {
        const t = Math.max(0, Math.min(1, amount))
        return Qt.rgba(
            from.r + (to.r - from.r) * t,
            from.g + (to.g - from.g) * t,
            from.b + (to.b - from.b) * t,
            from.a + (to.a - from.a) * t
        )
    }

    function pad2(value) {
        return value < 10 ? "0" + value : "" + value
    }

    function formatElapsed(totalSeconds) {
        const hours = Math.floor(totalSeconds / 3600)
        const minutes = Math.floor((totalSeconds % 3600) / 60)
        const seconds = totalSeconds % 60

        if (hours > 0)
            return pad2(hours) + ":" + pad2(minutes) + ":" + pad2(seconds)

        return pad2(minutes) + ":" + pad2(seconds)
    }

    function setExpanded(active) {
        expandAnimation.stop()
        expandAnimation.to = active ? 1 : 0
        expandAnimation.start()
    }

    function beginRecording() {
        elapsedSeconds = 0
        elapsedTimer.restart()
        pulseAnimation.stop()
        recordingColor = StyleRecording.fill
        pulseAnimation.start()

        if (root.expanded)
            setExpanded(true)
    }

    function endRecording() {
        elapsedSeconds = 0
        elapsedTimer.stop()
        pulseAnimation.stop()
        recordingColor = StyleRecording.fill
        setExpanded(false)
    }

    onExpandedChanged: setExpanded(expanded)

    Text {
        id: durationLabel

        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        text: root.formatElapsed(root.elapsedSeconds)
        color: root.trailForeground
        font.family: StyleTokens.fontMono
        font.pixelSize: StyleTokens.fontSizeSm
    }

    NumberAnimation {
        id: expandAnimation

        target: root
        property: "trailReveal"
        duration: StyleRecording.expandDuration
        easing.type: Easing.OutCubic
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
        running: Privacy.screenrecord
        repeat: true
        triggeredOnStart: false
        onTriggered: root.elapsedSeconds++
    }

    Connections {
        target: Privacy
        function onScreenrecordChanged() {
            if (Privacy.screenrecord)
                root.beginRecording()
            else
                root.endRecording()
        }
    }

    Component.onCompleted: {
        if (Privacy.screenrecord)
            root.beginRecording()
    }
}
