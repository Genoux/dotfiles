import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts
import qs
import qs.config

Rectangle {
    id: root

    property string iconText: ""
    property string iconFont: Style.fontIcon
    property bool iconVisible: iconText.length > 0
    property string iconSource: ""
    property int iconSourceSize: Style.iconSizeXs
    property string labelText: ""
    property color labelColor: Colors.base05
    property bool interactive: true

    signal clicked

    implicitWidth: content.implicitWidth + 12
    implicitHeight: Style.pillHeight
    radius: Style.radiusSm
    color: mouse.containsMouse && interactive ? Style.alphaLight : Style.transparent

    RowLayout {
        id: content

        anchors.centerIn: parent
        spacing: 3

        IconImage {
            visible: root.iconSource.length > 0
            width: root.iconSourceSize
            height: root.iconSourceSize
            source: root.iconSource
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            visible: root.iconVisible && root.iconSource.length === 0
            text: root.iconText
            color: Colors.base05
            font.family: root.iconFont
            font.pixelSize: Style.fontSizeSm
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: root.labelText
            color: root.labelColor
            font.family: Style.fontSans
            font.pixelSize: Style.fontSizeSm
            Layout.alignment: Qt.AlignVCenter
        }
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
            duration: Style.easeDurationFast
            easing.type: Easing.InOutQuad
        }
    }
}
