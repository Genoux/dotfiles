import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.services

Rectangle {
    id: root

    readonly property int horizontalPadding: 6
    readonly property int contentSpacing: 3

    implicitWidth: content.implicitWidth + horizontalPadding * 2
    implicitHeight: Style.pillHeight
    radius: Style.radiusSm
    color: mouse.containsMouse ? Style.alphaLight : Style.transparent

    RowLayout {
        id: content

        anchors.centerIn: parent
        spacing: root.contentSpacing

        Text {
            text: "󰔏"
            color: Colors.base05
            font.family: Style.fontIcon
            font.pixelSize: Style.fontSizeSm
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: Temperature.value
            color: Colors.base05
            font.family: Style.fontSans
            font.pixelSize: Style.fontSizeSm
            Layout.alignment: Qt.AlignVCenter
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        onClicked: Launchers.launchOrFocus("btop", "btop", "htop")
    }

    Behavior on color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.InOutQuad
        }
    }
}
