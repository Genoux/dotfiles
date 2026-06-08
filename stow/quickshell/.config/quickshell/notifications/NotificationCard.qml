import Quickshell
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

    property bool hovered: false

    width: Style.notificationWidth
    implicitHeight: content.implicitHeight + Style.notificationPadding * 2
    radius: Style.radiusMd
    color: Style.notificationSurface
    border.width: 1
    border.color: Style.notificationBorder

    Timer {
        id: expireTimer

        repeat: false
        onTriggered: Services.Notifications.expire(root.notification)
    }

    Component.onCompleted: root.startExpireTimer()
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
        anchors.margins: Style.notificationPadding
        spacing: 10

        Item {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: Style.notificationIconSize
            Layout.preferredHeight: Style.notificationIconSize
            clip: true

            Image {
                anchors.fill: parent
                anchors.margins: 2
                visible: root.hasImage
                source: root.notification.image
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(Style.notificationIconSize, Style.notificationIconSize)
            }

            IconImage {
                anchors.centerIn: parent
                visible: !root.hasImage
                width: Style.iconSizeMd
                height: Style.iconSizeMd
                implicitSize: Style.iconSizeMd
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
                font.family: Style.fontSans
                font.pixelSize: Style.fontSizeSm
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: root.body.length > 0
                text: root.body
                color: Colors.base05
                font.family: Style.fontSans
                font.pixelSize: Style.fontSizeSm
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

        return Style.notificationTimeout
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
