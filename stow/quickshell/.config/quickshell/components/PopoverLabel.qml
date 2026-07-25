import QtQuick
import qs
import qs.config

Text {
    id: label

    property int horizontalPadding: StylePopover.contentPaddingH

    width: implicitWidth + horizontalPadding * 2
    height: StylePopover.rowHeight
    leftPadding: horizontalPadding
    rightPadding: horizontalPadding
    color: Colors.base05
    font.family: StyleTokens.fontSans
    font.pixelSize: StyleTokens.fontSizeSm
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
}
