import Quickshell.Widgets
import QtQuick
import qs.config

Rectangle {
    id: root

    property string iconName: ""
    property color fillColor: Style.transparent
    property color borderColor: Style.transparent

    readonly property int iconSize: Style.iconSizeXs
    readonly property int padH: 4
    readonly property int padV: 2
    readonly property var resolvedSource: IconRegistry.source(iconName)
    readonly property bool usesLocalFile: resolvedSource.toString().startsWith("file:")

    implicitWidth: iconSize + padH * 2
    implicitHeight: iconSize + padV * 2
    radius: Style.radiusSm
    color: fillColor
    border.width: 1
    border.color: borderColor

    Image {
        anchors.centerIn: parent
        visible: root.usesLocalFile
        width: root.iconSize
        height: root.iconSize
        source: root.resolvedSource
        fillMode: Image.PreserveAspectFit
        sourceSize: Qt.size(root.iconSize, root.iconSize)
    }

    IconImage {
        anchors.centerIn: parent
        visible: !root.usesLocalFile
        width: root.iconSize
        height: root.iconSize
        implicitSize: root.iconSize
        source: root.resolvedSource
    }
}
