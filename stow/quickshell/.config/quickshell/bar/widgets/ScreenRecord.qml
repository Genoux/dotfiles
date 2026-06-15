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
    readonly property bool recording: Privacy.recording
    readonly property var recordMenuEntries: [{
        "label": "Region",
        "script": "system-screenrecord",
        "args": "region"
    }, {
        "label": "Region + audio",
        "script": "system-screenrecord",
        "args": "region audio"
    }, {
        "label": "Fullscreen",
        "script": "system-screenrecord",
        "args": "fullscreen"
    }, {
        "label": "Fullscreen + audio",
        "script": "system-screenrecord",
        "args": "fullscreen audio"
    }]
    readonly property bool expanded: root.hovered && recording
    readonly property color trailForeground: "#ffffff"
    readonly property color iconForeground: !recording ? Colors.base05 : mixColor(recordingColor, trailForeground, trailReveal)
    property bool menuVisible: false
    property real menuX: 0
    property real menuY: 0
    property color recordingColor: StyleRecording.fill
    property int elapsedSeconds: 0

    function mixColor(from, to, amount) {
        const t = Math.max(0, Math.min(1, amount));
        return Qt.rgba(from.r + (to.r - from.r) * t, from.g + (to.g - from.g) * t, from.b + (to.b - from.b) * t, from.a + (to.a - from.a) * t);
    }

    function runRecordAction(index) {
        const entry = recordMenuEntries[index];
        if (!entry || !entry.script)
            return ;

        const rawArgs = String(entry.args ?? "").trim();
        const args = rawArgs.length > 0 ? rawArgs.split(/\s+/) : [];
        console.log(`ScreenRecord action: ${entry.script} ${rawArgs}`);
        ShellActions.runLocalScript(String(entry.script), args);
        menuVisible = false;
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

    function setExpanded(active) {
        expandAnimation.stop();
        expandAnimation.to = active ? 1 : 0;
        expandAnimation.start();
    }

    function beginRecording() {
        elapsedSeconds = 0;
        elapsedTimer.restart();
        pulseAnimation.stop();
        recordingColor = StyleRecording.fill;
        pulseAnimation.start();
        if (root.expanded)
            setExpanded(true);

    }

    function endRecording() {
        elapsedSeconds = 0;
        elapsedTimer.stop();
        pulseAnimation.stop();
        recordingColor = StyleRecording.fill;
        setExpanded(false);
    }

    iconSource: IconRegistry.barIcon("media", "record")
    foreground: iconForeground
    background: recording ? Qt.rgba(recordingColor.r, recordingColor.g, recordingColor.b, recordingColor.a * trailReveal) : StyleTokens.transparent
    hoverBackground: StyleTokens.alphaLight
    interactive: true
    animateColor: false
    manageHoverColor: !recording
    clipContent: true
    trailGap: 2
    trailPaddingRight: 3
    trailWidth: durationLabel.implicitWidth
    onClicked: (mouse) => {
        if (Privacy.recording) {
            ShellActions.runLocalScript("system-screenrecord");
            return ;
        }
        const point = root.mapToItem(null, mouse.x, mouse.y);
        menuX = point.x;
        menuY = point.y;
        menuVisible = !menuVisible;
    }
    onExpandedChanged: setExpanded(expanded)
    Component.onCompleted: {
        if (Privacy.recording)
            root.beginRecording();

    }

    Text {
        id: durationLabel

        anchors.verticalCenter: parent.verticalCenter
        text: root.formatElapsed(root.elapsedSeconds)
        color: root.trailForeground
        font.family: StyleTokens.fontMono
        font.pixelSize: StyleTokens.fontSizeSm
        height: root.labelLineHeight
        verticalAlignment: Text.AlignVCenter
    }

    PopupWindow {
        id: recordMenuWindow

        anchor.window: root.barWindow
        anchor.rect.x: Math.round(root.menuX - recordMenuWindow.implicitWidth / 2)
        anchor.rect.y: Math.round(root.menuY - recordMenuWindow.implicitHeight - StylePopover.anchorGap)
        anchor.rect.width: 1
        anchor.rect.height: 1
        grabFocus: true
        color: StyleTokens.transparent
        visible: root.menuVisible
        implicitWidth: recordMenu.implicitWidth
        implicitHeight: recordMenu.implicitHeight
        onClosed: root.menuVisible = false

        PopoverMenu {
            id: recordMenu

            active: root.menuVisible
            entries: root.recordMenuEntries
            onSelected: (index) => root.runRecordAction(index)
        }
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
        running: Privacy.recording
        repeat: true
        triggeredOnStart: false
        onTriggered: root.elapsedSeconds++
    }

    Connections {
        function onRecordingChanged() {
            if (Privacy.recording)
                root.beginRecording();
            else
                root.endRecording();
        }

        target: Privacy
    }

}
