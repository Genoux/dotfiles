import QtQuick
import QtQuick.Controls as Controls
import qs
import qs.config

Controls.TextField {
    id: root
    implicitHeight: StyleManager.inputHeight
    color: StyleManager.textColor
    placeholderTextColor: StyleManager.textColor
    selectionColor: Colors.base03
    selectedTextColor: StyleManager.textColor
    font.family: StyleTokens.fontSans
    font.pixelSize: StyleTokens.fontSizeSm
    leftPadding: StyleTokens.space12
    background: Rectangle {
        radius: StyleTokens.radiusSm
        color: StyleTokens.alphaLight
        border.width: StyleTokens.borderWidth
        border.color: root.activeFocus ? StyleManager.textColor : StyleOverlay.borderSubtle
    }
    Accessible.name: placeholderText
}
