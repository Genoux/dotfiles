import Quickshell
import Quickshell.Widgets
import QtQuick
import Qt5Compat.GraphicalEffects
import qs
import qs.config

Rectangle {
    id: root

    property string iconName: ""
    property string iconSource: ""
    property color background: Style.transparent
    property color hoverBackground: Style.alphaLight
    property color borderColor: Style.transparent
    property int borderWidth: 0
    property color foreground: Colors.base05
    property int iconSize: Style.iconSize
    property bool interactive: false
    readonly property var resolvedSource: iconSource || IconRegistry.source(iconName)
    readonly property bool usesBundledIcon: iconSource.length === 0 && IconRegistry.hasOverride(iconName)

    signal clicked(var mouse)

    implicitWidth: Style.pillWidth
    implicitHeight: Style.pillHeight
    radius: Style.radiusSm
    color: mouseArea.containsMouse ? hoverBackground : background
    border.width: borderWidth
    border.color: borderColor

    Item {
        anchors.centerIn: parent
        visible: root.usesBundledIcon && root.resolvedSource.toString().length > 0
        width: root.iconSize
        height: root.iconSize

        Image {
            id: bundledIcon

            anchors.fill: parent
            source: root.resolvedSource
            fillMode: Image.PreserveAspectFit
            sourceSize: Qt.size(root.iconSize, root.iconSize)
            visible: false
        }

        ColorOverlay {
            anchors.fill: parent
            source: bundledIcon
            color: root.foreground
        }
    }

    IconImage {
        anchors.centerIn: parent
        visible: !root.usesBundledIcon && root.resolvedSource.toString().length > 0
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
