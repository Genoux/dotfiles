import QtQuick
import QtQuick.Layouts
import qs
import qs.config

Rectangle {
    id: root

    property string iconText: ""
    property string iconFont: Style.fontIcon
    property bool iconVisible: iconText.length > 0
    property string labelText: ""

    signal clicked

    implicitWidth: content.implicitWidth + 12
    implicitHeight: Style.pillHeight
    radius: Style.radiusSm
    color: mouse.containsMouse ? Style.alphaLight : Style.transparent

    RowLayout {
        id: content

        anchors.centerIn: parent
        spacing: 3

        Text {
            visible: root.iconVisible
            text: root.iconText
            color: Colors.base05
            font.family: root.iconFont
            font.pixelSize: Style.fontSizeSm
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.labelText
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
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Style.easeDurationFast
            easing.type: Easing.InOutQuad
        }
    }
}
