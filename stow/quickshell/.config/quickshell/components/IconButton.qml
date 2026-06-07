import Quickshell
import Quickshell.Widgets
import QtQuick
import qs
import qs.config

Rectangle {
    id: root

    property string iconName: ""
    property string iconSource: ""
    property color background: Style.transparent
    property color hoverBackground: Style.alphaLight
    property color foreground: Colors.base05
    property int iconSize: Style.iconSize
    property bool interactive: false
    readonly property var resolvedSource: iconSource || IconRegistry.source(iconName)
    readonly property bool usesLocalFile: resolvedSource.toString().startsWith("file:")

    signal clicked(var mouse)

    implicitWidth: Style.pillHeight
    implicitHeight: Style.pillHeight
    radius: Style.radiusSm
    color: mouseArea.containsMouse ? hoverBackground : background

    Image {
        anchors.centerIn: parent
        visible: root.usesLocalFile && root.resolvedSource.toString().length > 0
        width: root.iconSize
        height: root.iconSize
        source: root.resolvedSource
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(root.iconSize, root.iconSize)
    }

    IconImage {
        anchors.centerIn: parent
        visible: !root.usesLocalFile && root.resolvedSource.toString().length > 0
        width: root.iconSize
        height: root.iconSize
        implicitSize: root.iconSize
        source: root.resolvedSource
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        acceptedButtons: root.interactive ? Qt.LeftButton | Qt.RightButton | Qt.MiddleButton : Qt.NoButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
        hoverEnabled: true
        onClicked: (mouse) => root.clicked(mouse)
    }

    Behavior on color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.InOutQuad
        }
    }
}
