import QtQuick
import qs
import qs.config

Rectangle {
    id: root

    property string text: ""
    property color foreground: Colors.base05
    property color background: Style.transparent
    property color hoverBackground: Style.alphaLight
    property string fontFamily: Style.fontSans
    property int fontSize: Style.fontSizeSm
    property int horizontalPadding: 8
    property int minimumWidth: 0
    property bool interactive: false

    signal clicked

    implicitWidth: Math.max(minimumWidth, label.implicitWidth + horizontalPadding * 2)
    implicitHeight: Style.pillHeight
    radius: Style.radiusSm
    color: mouse.containsMouse ? hoverBackground : background

    Text {
        id: label

        anchors.centerIn: parent
        text: root.text
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        acceptedButtons: root.interactive ? Qt.LeftButton : Qt.NoButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        onClicked: root.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.InOutQuad
        }
    }
}
