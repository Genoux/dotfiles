import QtQuick
import qs
import qs.config

// Muted centered line standing in for absent content: empty lists, disabled
// hardware, work in progress. Wraps the label in an Item so the band can hold
// a fixed height independent of the text's own metrics.
Item {
    property alias text: message.text
    property alias topPadding: message.topPadding
    property alias verticalAlignment: message.verticalAlignment

    implicitHeight: StylePopover.rowHeight
    height: implicitHeight

    Text {
        id: message

        anchors.fill: parent
        leftPadding: StylePopover.contentPaddingH
        rightPadding: StylePopover.contentPaddingH
        color: Colors.base04
        font.family: StyleTokens.fontSans
        font.pixelSize: StyleTokens.fontSizeSm
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
}
