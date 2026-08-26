import QtQuick
import qs
import qs.config

// Eyebrow that titles a group of rows, with an optional control opposite it.
// The control belongs to the section it acts on — a scan button sits on the
// list it populates rather than floating above the whole panel.
Item {
    id: section

    property string label: ""
    // Air added above the label when this section follows other content, so a
    // group separates from the one before it without a rule between them.
    property int topGap: 0
    default property alias trailing: trailingSlot.data

    implicitWidth: labelText.implicitWidth + StylePopover.contentPaddingH * 2 + trailingSlot.width
    implicitHeight: StylePopover.sectionHeight + topGap
    height: implicitHeight

    EyebrowLabel {
        id: labelText

        anchors.left: parent.left
        anchors.leftMargin: StylePopover.contentPaddingH
        anchors.right: trailingSlot.left
        anchors.rightMargin: StyleTokens.space8
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: section.topGap / 2
        text: section.label
        elide: Text.ElideRight
    }

    Item {
        id: trailingSlot

        anchors.right: parent.right
        anchors.rightMargin: StylePopover.contentPaddingH - StylePopover.ghostPaddingH
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: section.topGap / 2
        width: childrenRect.width
        height: childrenRect.height
    }
}
