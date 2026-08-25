import QtQuick
import qs
import qs.config

// Uppercase micro-label that titles a group, column, or figure. Small, spaced,
// and dimmed so it reads as chrome naming the content rather than as content.
// Size is the one contextual dimension — a calendar column header carries more
// weight than a section eyebrow — so callers may override it.
Text {
    color: Colors.base04
    opacity: StylePopover.sectionLabelOpacity
    font.family: StyleTokens.fontSans
    font.pixelSize: StyleTokens.fontSizeXs
    font.weight: Font.Medium
    font.capitalization: Font.AllUppercase
    font.letterSpacing: StylePopover.sectionLetterSpacing
    verticalAlignment: Text.AlignVCenter
}
