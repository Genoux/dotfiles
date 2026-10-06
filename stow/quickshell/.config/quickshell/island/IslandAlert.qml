import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.config
import qs.notifications
import qs.services as Services

// The island opened into a notification: its icon, what it says, its actions,
// and an X. Clicking the card does what the notification
// is for; hovering holds it.
//
// What it shows is copied when a notification arrives. Dismissing destroys the
// notification at once, and the card has to keep saying the same thing while it
// folds back into the pill.
Item {
    id: root

    property var notification: null
    property var shown: ({})
    // The notification on screen before this one. It reads as null once that
    // one is dismissed, so only a true replacement swaps in place.
    property var previous: null

    readonly property bool hovered: hover.hovered
    readonly property var actions: (shown.actions ?? []).slice(0, StyleIsland.alertMaxActions)

    // The band the icon, the text and the X share. All three centre on it: an
    // icon hung from the top padding sat above a taller text block.
    readonly property real headHeight: Math.max(StyleIsland.alertIconSize, textColumn.implicitHeight)

    implicitWidth: StyleIsland.alertWidth
    implicitHeight: StyleIsland.alertPadding * 2 + headHeight
        + (actions.length > 0 ? StyleIsland.alertActionsGap + StyleIsland.alertActionHeight : 0)

    onNotificationChanged: {
        if (notification && previous)
            swap.restart()
        else
            adopt()
        previous = notification
    }
    onHoveredChanged: restartExpiry()

    function adopt() {
        if (!notification) {
            expireTimer.stop()
            return
        }

        shown = {
            "title": Services.Notifications.cleanText(notification.summary) || notification.appName || "",
            "body": Services.Notifications.cleanText(notification.body),
            "image": notification.image ?? "",
            "iconName": notification.appIcon || notification.desktopEntry || "",
            "actions": Services.Notifications.namedActions(notification)
        }
        restartExpiry()
    }

    function restartExpiry() {
        expireTimer.stop()
        const interval = Services.Notifications.expiryMs(notification)
        if (!notification || hovered || interval <= 0)
            return

        expireTimer.interval = interval
        expireTimer.start()
    }

    // A newer notification replaces this one in place: the old words leave,
    // the shape resizes to the new ones, the new words arrive.
    SequentialAnimation {
        id: swap

        NumberAnimation {
            target: face
            property: "opacity"
            to: 0
            duration: StyleIsland.alertSwapOut
            easing.type: StyleTokens.easeFade
        }

        ScriptAction {
            script: root.adopt()
        }

        NumberAnimation {
            target: face
            property: "opacity"
            to: 1
            duration: StyleIsland.alertSwapIn
            easing.type: StyleTokens.easeFade
        }
    }

    Timer {
        id: expireTimer

        onTriggered: Services.Notifications.expire(root.notification)
    }

    Connections {
        target: Services.Notifications

        function onRefreshed(notification) {
            if (notification === root.notification)
                root.adopt()
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const notification = root.notification
            Services.Notifications.activate(notification)
            Services.Notifications.dismiss(notification)
        }
    }

    Item {
        id: face

        anchors.fill: parent

        NotificationIcon {
            x: StyleIsland.alertPadding
            y: StyleIsland.alertPadding + Math.round((root.headHeight - height) / 2)
            width: StyleIsland.alertIconSize
            height: width
            bare: true
            image: root.shown.image ?? ""
            iconName: root.shown.iconName ?? ""
        }

        ColumnLayout {
            id: textColumn

            x: StyleIsland.alertPadding + StyleIsland.alertIconSize + StyleIsland.alertIconGap
            y: StyleIsland.alertPadding + Math.round((root.headHeight - implicitHeight) / 2)
            width: parent.width - x - StyleIsland.alertTrailingReserve
            spacing: StyleIsland.alertTitleGap

            Text {
                Layout.fillWidth: true
                text: root.shown.title ?? ""
                color: Colors.base07
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeMd
                font.weight: Font.DemiBold
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: root.shown.body ?? ""
                color: Colors.base05
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                textFormat: Text.PlainText
                wrapMode: Text.WordWrap
                maximumLineCount: StyleIsland.alertBodyLines
                elide: Text.ElideRight
            }
        }

        Row {
            id: actionRow

            readonly property real buttonWidth: (width - spacing * Math.max(0, root.actions.length - 1)) / Math.max(1, root.actions.length)

            x: StyleIsland.alertPadding
            y: StyleIsland.alertPadding + root.headHeight + StyleIsland.alertActionsGap
            width: parent.width - StyleIsland.alertPadding * 2
            visible: root.actions.length > 0
            spacing: StyleIsland.alertActionSpacing

            Repeater {
                model: root.actions

                PillButton {
                    required property var modelData

                    width: actionRow.buttonWidth
                    height: StyleIsland.alertActionHeight
                    text: modelData.text
                    clipContent: true
                    onClicked: {
                        const notification = root.notification
                        modelData.invoke()
                        Services.Notifications.dismiss(notification)
                    }
                }
            }
        }
    }

    Item {
        x: parent.width - StyleIsland.alertPadding - (StyleIsland.alertDismissSize + width) / 2
        y: StyleIsland.alertPadding + Math.round((root.headHeight - height) / 2)
        width: StyleIsland.alertDismissHitSize
        height: width

        Rectangle {
            anchors.centerIn: parent
            width: StyleIsland.alertDismissSize
            height: width
            radius: width / 2
            color: dismissArea.containsMouse ? StyleTokens.alphaActive : StyleTokens.alphaLight

            ThemedIcon {
                anchors.centerIn: parent
                size: StyleIsland.alertDismissIconSize
                source: IconRegistry.source("window-close-symbolic")
                tint: Colors.base06
            }
        }

        MouseArea {
            id: dismissArea

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Services.Notifications.dismiss(root.notification)
        }
    }
}
