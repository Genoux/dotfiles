import QtQuick
import qs
import qs.config

// Sentence-case label that titles a group, column, or figure. Dimmed so it
// reads as chrome naming the content rather than as content. Size is the one
// contextual dimension, so callers may override it.
Text {
    color: Colors.base04
    font.family: StyleTokens.fontSans
    font.pixelSize: StyleTokens.fontSizeSm
    font.weight: Font.Medium
    verticalAlignment: Text.AlignVCenter
}
