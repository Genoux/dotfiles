import QtQuick
import qs.config

// Trailing control for a list row: one glyph that means "step this row back",
// applied twice.
//
// A connected row's X drops the link, which demotes the row into the Paired or
// Saved section below it. From there the same X forgets the device outright.
// The two actions are stages of one retreat, not a pair of choices — offering
// Disconnect and Forget side by side asks the reader to rank two
// destructive-looking words before they have decided anything.
//
// Both stages arm before they act. Gating only the irreversible one would be
// defensible in isolation, but this is a single glyph in a fixed position whose
// meaning changes with the row's state: if it sometimes fires on the first
// click and sometimes asks, the reader cannot learn what a click costs. Arming
// both makes the rule uniform — the X always asks, and the word it becomes
// says which retreat is on offer.
//
// Hidden at rest so the row stays quiet. Declare it above the row's own
// MouseArea so its clicks land here rather than reaching the row underneath.
Row {
    id: actions

    required property bool hovered
    property bool showDisconnect: false
    property bool showRemove: false
    property string removeConfirmText: "Forget"
    // A recycled list row may point at a different target after its model is
    // resorted or refreshed. Never carry an armed destructive action across
    // that identity change.
    property var actionKey: undefined
    // An action already in flight has nothing useful to offer.
    property bool busy: false

    property bool confirming: false
    readonly property string confirmText: showDisconnect ? "Disconnect" : removeConfirmText

    // The row changed stage underneath an armed button, so the word the reader
    // was deciding about is no longer the word this click would act on. Drop
    // the arm rather than swap the label out from under them.
    onShowDisconnectChanged: confirming = false
    onActionKeyChanged: confirming = false

    signal disconnectRequested()
    signal removeRequested()

    z: 1
    visible: (showDisconnect || showRemove) && !busy
    opacity: hovered ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: StyleTokens.easeDurationFast
            easing.type: StyleTokens.easeStandard

            // Disarm only once the controls are gone. Clearing on hover-out
            // instead would swap the word back to the glyph in full view, so the
            // pointer leaving would read as a flicker rather than a fade — and
            // the label the reader was deciding about would vanish before the
            // thing holding it did. The confirmation is still dropped, one fade
            // later, so a later hover cannot act on a single click.
            onRunningChanged: {
                if (!running && !actions.hovered)
                    actions.confirming = false
            }
        }
    }

    PillButton {
        id: pill

        anchors.verticalCenter: parent.verticalCenter
        iconName: actions.confirming ? "" : "window-close-symbolic"
        iconSize: StyleControl.iconSizeSm
        text: actions.confirming ? actions.confirmText : ""
        paddingHorizontal: actions.confirming ? StylePopover.pillPaddingH : StylePopover.iconButtonPadding
        paddingVertical: StylePopover.iconButtonPadding
        interactive: actions.hovered
        // Arming swaps the glyph for a word, which is a size change as much as
        // a content change. Clipping lets the pill's own growth uncover the
        // centred label instead of the label appearing beside a pill that has
        // already jumped to its new width.
        //
        // Only the width moves. The pill is verticalCenter-anchored, so letting
        // the height animate too would re-centre it every frame for a 1px
        // change — read as shimmer, not motion. Holding one padding keeps the
        // height fixed, which is why there is no Behavior on height here.
        clipContent: true
        // Button sizes itself from its RowLayout, whose implicitWidth goes
        // stale when the icon slot swaps places with the label — it keeps
        // reporting the glyph's width, so the word overflows a pill still
        // sized for the X. Measuring the word directly is both the fix and
        // what makes the morph animatable: two known widths to travel between.
        width: actions.confirming ? Math.ceil(confirmMetrics.width) + StylePopover.pillPaddingH * 2 : StyleControl.iconSizeSm + StylePopover.iconButtonPadding * 2

        TextMetrics {
            id: confirmMetrics

            font.family: pill.fontFamily
            font.pixelSize: pill.fontSize
            text: actions.confirmText
        }

        Behavior on width {
            NumberAnimation {
                duration: StyleTokens.easeDurationInstant
                easing.type: StyleTokens.easeStandard
            }

        }

        onClicked: {
            if (!actions.confirming)
                actions.confirming = true
            else if (actions.showDisconnect)
                actions.disconnectRequested()
            else
                actions.removeRequested()
        }
    }
}
