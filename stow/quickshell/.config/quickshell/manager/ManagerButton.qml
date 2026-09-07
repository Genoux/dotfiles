import QtQuick
import qs.components
import qs.config

PillButton {
    id: root
    foreground: StyleManager.textColor
    radius: StyleTokens.radiusXs
    minimumHeight: StyleTokens.space8 * 4
    background: StyleTokens.transparent
    hoverBackground: StyleTokens.alphaActive
    activeFocusOnTab: true
    opacity: enabled ? 1 : StyleTokens.opacityDisabled
    borderColor: activeFocus ? foreground : StyleOverlay.borderSubtle
    Keys.onReturnPressed: clicked(null)
    Keys.onSpacePressed: clicked(null)
    onActiveFocusChanged: {
        if (!activeFocus)
            return
        for (let ancestor = parent; ancestor; ancestor = ancestor.parent) {
            if (ancestor.contentY === undefined || ancestor.contentHeight === undefined)
                continue
            const position = mapToItem(ancestor.contentItem, 0, 0)
            if (position.y < ancestor.contentY)
                ancestor.contentY = position.y
            else if (position.y + height > ancestor.contentY + ancestor.height)
                ancestor.contentY = position.y + height - ancestor.height
            break
        }
    }
    Accessible.role: Accessible.Button
    Accessible.name: text
    Accessible.onPressAction: if (enabled) clicked(null)
}
