import Quickshell
import QtQuick
import qs
import qs.config
import qs.components
import qs.services

Rectangle {
    id: root

    readonly property bool recording: Privacy.screenrecord
    readonly property bool expanded: hoverHandler.hovered && recording
    readonly property color hoverContent: "#ffffff"
    readonly property int edgePadding: 4
    readonly property int iconGap: 2
    readonly property int timerContentWidth: durationLabel.implicitWidth
    readonly property int expandedContentWidth: Style.pillWidth + iconGap + timerContentWidth
    readonly property int expandedWidth: edgePadding * 2 + expandedContentWidth
    readonly property int expandedExtra: expandedWidth - Style.pillWidth
    readonly property color iconForeground: !recording
        ? Colors.base05
        : mixColor(recordingColor, hoverContent, expandProgress)
    readonly property color backgroundFill: !recording
        ? (hoverHandler.hovered ? Style.alphaLight : Style.transparent)
        : Qt.rgba(recordingColor.r, recordingColor.g, recordingColor.b, recordingColor.a * expandProgress)

    width: Style.pillWidth + expandProgress * expandedExtra
    implicitWidth: width
    implicitHeight: Style.pillHeight
    radius: Style.radiusSm
    clip: true
    color: backgroundFill

    property real expandProgress: 0
    property color recordingColor: Style.recording
    property int elapsedSeconds: 0

    HoverHandler {
        id: hoverHandler
    }

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
        recordingColor = Style.recording
        pulseAnimation.start()

        if (root.expanded)
            setExpanded(true)
    }

    function endRecording() {
        elapsedSeconds = 0
        elapsedTimer.stop()
        pulseAnimation.stop()
        recordingColor = Style.recording
        setExpanded(false)
    }

    onExpandedChanged: setExpanded(expanded)

    Row {
        id: contentRow

        anchors.centerIn: parent
        spacing: root.iconGap * root.expandProgress

        IconButton {
            id: recordButton

            width: Style.pillWidth
            height: Style.pillHeight
            iconName: "media-record-symbolic"
            iconSize: Style.iconSizeMd
            foreground: root.iconForeground
            background: Style.transparent
            hoverBackground: Style.transparent
            animateColor: false
            interactive: false
        }

        Item {
            id: durationReveal

            height: parent.height
            width: root.timerContentWidth * root.expandProgress
            clip: true

            Text {
                id: durationLabel

                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                text: root.formatElapsed(root.elapsedSeconds)
                color: root.hoverContent
                font.family: Style.fontMono
                font.pixelSize: Style.fontSizeSm
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellActions.run(Privacy.screenrecord ? ["system-screenrecord"] : ["system-screenrecord", "region"])
    }

    NumberAnimation {
        id: expandAnimation

        target: root
        property: "expandProgress"
        duration: Style.mediaControlsRevealDuration
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: pulseAnimation
        loops: Animation.Infinite

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: Style.recordingPulse
            duration: Style.recordingPulseDuration
            easing.type: Easing.InOutSine
        }

        ColorAnimation {
            target: root
            property: "recordingColor"
            to: Style.recording
            duration: Style.recordingPulseDuration
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
