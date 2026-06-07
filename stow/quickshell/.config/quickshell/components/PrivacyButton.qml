import QtQuick
import qs.config
import qs.components

IconButton {
    id: root

    property color fillColor: Style.transparent

    iconSize: Style.iconSizeXs
    background: fillColor
    hoverBackground: fillColor
    borderWidth: 1
}
