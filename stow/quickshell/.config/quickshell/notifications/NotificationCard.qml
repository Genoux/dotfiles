import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.components
import qs.services as Services

Rectangle {
    id: root

    required property var notification

    readonly property string summary: Services.Notifications.cleanText(notification?.summary)
    readonly property string body: Services.Notifications.cleanText(notification?.body)
    readonly property var namedActions: Services.Notifications.namedActions(notification)

    property bool hovered: false

    // Cards rest at the left of a window widened by the drag runway, so x is
    // free to travel right without an anchor fighting it.
    readonly property real restingX: 0
    readonly property real dragOffset: Math.max(0, x - restingX)
    readonly property bool dragging: cardArea.drag.active

    width: StyleNotification.width
    x: restingX
    implicitHeight: content.implicitHeight + StyleNotification.padding * 2
    opacity: 1 - Math.min(1, dragOffset / StyleNotification.dragRunway)
    radius: StyleTokens.radiusLg
    color: StyleOverlay.surface

    NumberAnimation {
        id: returnAnimation

        target: root
        property: "x"
        to: root.restingX
        duration: StyleTokens.motionFeedbackDuration
        easing.type: StyleTokens.easeStandard
    }

    NumberAnimation {
        id: dismissAnimation

        target: root
        property: "x"
        to: root.restingX + StyleNotification.dragRunway
        duration: StyleTokens.motionFeedbackDuration
        easing.type: StyleTokens.easeStandard
        onFinished: Services.Notifications.dismiss(root.notification)
    }

    Timer {
        id: expireTimer

        repeat: false
        onTriggered: Services.Notifications.expire(root.notification)
    }

    Component.onCompleted: root.startExpireTimer()
    onNotificationChanged: root.startExpireTimer()
    onDraggingChanged: root.startExpireTimer()

    Connections {
        target: Services.Notifications

        function onRefreshed(notification) {
            if (notification === root.notification)
                root.startExpireTimer()
        }
    }
    onHoveredChanged: {
        if (hovered || dragging)
            expireTimer.stop()
        else
            root.startExpireTimer()
    }

    RowLayout {
        id: content
        z: 1

        anchors.fill: parent
        anchors.margins: StyleNotification.padding
        spacing: StyleTokens.space10

        NotificationIcon {
            Layout.alignment: Qt.AlignTop
            Layout.preferredWidth: StyleNotification.iconSize
            Layout.preferredHeight: StyleNotification.iconSize
            image: root.notification?.image ?? ""
            iconName: root.notification?.appIcon ?? ""
            desktopEntry: root.notification?.desktopEntry ?? ""
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: StyleTokens.space4

            Text {
                Layout.fillWidth: true
                visible: root.summary.length > 0
                text: root.summary
                color: Colors.base07
                font.family: StyleTokens.fontSans
                font.pixelSize: StyleTokens.fontSizeSm
                font.weight: Font.Medium
                textFormat: Text.PlainText
                elide: Text.ElideRight
            }

            Flow {
                id: actionFlow

                Layout.fillWidth: true
                Layout.preferredHeight: childrenRect.height
                visible: root.namedActions.length > 0
                spacing: StyleTokens.space6

                Repeater {
                    model: root.namedActions

                    PillButton {
                        required property var modelData

                        text: modelData.text
                        width: Math.min(implicitWidth, actionFlow.width)
                        clipContent: true
                        onClicked: modelData.invoke()
                    }
                }
            }

            Text {
                Layout.fillWidth: true
                visible: root.body.length > 0
                text: root.body
                color: Colors.base04
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
        id: cardArea

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: false
        cursorShape: Qt.PointingHandCursor
        drag.target: root
        drag.axis: Drag.XAxis
        drag.minimumX: root.restingX
        drag.maximumX: root.restingX + StyleNotification.dragRunway

        onPressed: {
            expireTimer.stop()
            returnAnimation.stop()
        }
        onReleased: {
            if (root.dragOffset >= StyleNotification.dragThreshold) {
                dismissAnimation.restart()
                return
            }
            returnAnimation.restart()
            root.startExpireTimer()
        }

        onClicked: (mouse) => {
            if (mouse.button === Qt.RightButton) {
                Services.Notifications.dismiss(root.notification)
                return
            }

            Services.Notifications.activate(root.notification)
        }
    }

    function startExpireTimer() {
        const nextInterval = Services.Notifications.expiryMs(notification)
        expireTimer.stop()

        if (nextInterval <= 0 || hovered || dragging)
            return

        expireTimer.interval = nextInterval
        expireTimer.restart()
    }
}
