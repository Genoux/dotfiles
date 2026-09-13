import QtQuick
import QtQuick.Layouts
import qs.config

// A run of peers that share one hover indicator instead of each lighting up
// alone. The travelling fill is the feedback, so the children must not paint
// their own — see SlidingHighlight for why movement rather than a fade.
//
// Only direct children are tracked. The indicator is positioned in this item's
// own coordinates, and something nested a level deeper is by definition sitting
// inside its own group rather than in this run of neighbours.
Item {
    id: root

    default property alias content: row.data
    property alias spacing: row.spacing

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    // The run owns hover feedback for its children, so it switches theirs off
    // rather than making every call site remember to. Assigning clears whatever
    // binding the child had on hoverBackground; nothing binds it today, and a
    // child that needs a fill of its own is not a peer and does not belong here.
    Component.onCompleted: {
        for (const child of row.children) {
            if (child.hoverBackground !== undefined)
                child.hoverBackground = StyleTokens.transparent
        }
    }

    SlidingHighlight {
        run: row
    }

    RowLayout {
        id: row

        // Left-anchored, not centred: the indicator is positioned in this
        // item's coordinates while the children report x in the row's, so any
        // offset between the two would slide the fill off its own target.
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: StyleTokens.space2
    }
}
