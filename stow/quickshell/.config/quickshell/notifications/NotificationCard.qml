import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.services as Services

Rectangle {
    id: root

    required property var notification

    readonly property string summary: cleanText(notification?.summary ?? "")
    readonly property string body: cleanText(notification?.body ?? "")
    readonly property string iconName: notification?.appIcon || notification?.desktopEntry || "dialog-information-symbolic"
    readonly property bool hasImage: (notification?.image ?? "").length > 0

    // Clipboard image preview for screenshot tools (Satty, Flameshot, Spectacle)
    readonly property bool isClipboardCopy: {
        const name = (notification?.appName ?? "").toLowerCase()
        const summ = root.summary.toLowerCase()
        const bod = root.body.toLowerCase()
        return (name.includes("satty") || name.includes("flameshot") || name.includes("spectacle"))
            && (summ.includes("clipboard") || bod.includes("clipboard"))
    }

    property string clipboardImagePath: ""
    readonly property bool hasClipboardImage: clipboardImagePath.length > 0

    property bool hovered: false

    width: StyleNotification.width
    implicitHeight: content.implicitHeight + StyleNotification.padding * 2
    radius: StyleTokens.radiusMd
    color: StyleNotification.surface
    border.width: 1
    border.color: StyleNotification.border

    Timer {
        id: expireTimer

        repeat: false
        onTriggered: Services.Notifications.expire(root.notification)
    }

    Process {
        id: clipboardSaveProcess

        property string outPath: `/tmp/qs-notif-clip-${notification?.id ?? 0}.png`
        command: ["sh", "-c", `wl-paste --type image/png > '${outPath}' 2>/dev/null && echo ok`]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                if (line.trim() === "ok")
                    root.clipboardImagePath = clipboardSaveProcess.outPath
            }
        }
    }

    Component.onCompleted: {
        root.startExpireTimer()
        if (root.isClipboardCopy)
            clipboardSaveProcess.running = true
    }
    onNotificationChanged: root.startExpireTimer()
    onHoveredChanged: {
        if (hovered)
            expireTimer.stop()
        else
            root.startExpireTimer()
    }

    RowLayout {
        id: content

        anchors.fill: parent
        anchors.margins: StyleNotification.padding
        spacing: 10

        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: StyleNotification.iconSize
            Layout.preferredHeight: StyleNotification.iconSize
            clip: true

            // Clipboard screenshot thumbnail (fills icon slot)
            Image {
                anchors.fill: parent
                visible: root.hasClipboardImage
                source: root.clipboardImagePath.length > 0 ? `file://${root.clipboardImagePath}` : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(StyleNotification.iconSize * 2, StyleNotification.iconSize * 2)
            }

            // Regular notification image
            Image {
                anchors.fill: parent
                anchors.margins: 2
                visible: !root.hasClipboardImage && root.hasImage
                source: root.notification?.image ?? ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(StyleNotification.iconSize, StyleNotification.iconSize)
            }

            IconImage {
                anchors.centerIn: parent
                visible: !root.hasClipboardImage && !root.hasImage
                width: StyleControl.iconSizeMd
                height: StyleControl.iconSizeMd
                implicitSize: StyleControl.iconSizeMd
                source: Quickshell.iconPath(root.iconName, "dialog-information-symbolic")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                Layout.fillWidth: true
                visible: root.summary.length > 0
                text: root.summary
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.body.length > 0
                text: root.body
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
            }
        }
    }

    HoverHandler {
        id: hoverHandler

        onHoveredChanged: root.hovered = hoverHandler.hovered
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: false
        cursorShape: Qt.PointingHandCursor

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Services.Notifications.dismiss(root.notification)
                return
            }

            root.activate()
        }
    }

    function expiryMs() {
        const requestedTimeout = notification?.expireTimeout ?? 0
        if (requestedTimeout > 0)
            return Math.max(1200, requestedTimeout * 1000)

        return StyleNotification.timeout
    }

    function startExpireTimer() {
        const nextInterval = expiryMs()
        expireTimer.stop()

        if (nextInterval <= 0 || hovered)
            return

        expireTimer.interval = nextInterval
        expireTimer.restart()
    }

    function activate() {
        const actions = notification?.actions ?? []
        const action = actions.find((candidate) => candidate.identifier === "")
            ?? actions.find((candidate) => candidate.identifier === "default")
            ?? actions[0]

        if (action) {
            action.invoke()
            return
        }

        const entryId = notification?.desktopEntry ?? ""
        if (entryId.length === 0)
            return

        const normalizedId = entryId.endsWith(".desktop") ? entryId : `${entryId}.desktop`
        const entry = DesktopEntries.applications.values.find((candidate) => {
            return candidate.id === entryId
                || candidate.id === normalizedId
                || candidate.id.replace(/\.desktop$/, "") === entryId
        })

        entry?.execute()
    }

    function cleanText(value) {
        return (value ?? "").toString().replace(/\s+/g, " ").trim()
    }
}
