import QtQuick
import qs.config

// Trailing controls for a list row: the reversible action stated plainly, and the
// destructive one behind a glyph that arms into a worded confirm.
//
// Both are offered at once, which is what a desktop settings panel does — macOS,
// Windows and GNOME all put Disconnect and Forget side by side behind one
// overflow affordance. Requiring a disconnect before a forget is available reads
// as tidy and is not: "I am done with this network for good" is the common case,
// and sequencing it turns one decision into two.
//
// Hidden at rest so the row stays quiet. Declare it above the row's own
// MouseArea so its clicks land here rather than reaching the row underneath.
Row {
    id: actions

    required property bool hovered
    property bool showDisconnect: false
    property bool showRemove: false
    // An action already in flight has nothing useful to offer.
    property bool busy: false

    property bool confirming: false

    signal disconnectRequested()
    signal removeRequested()

    z: 1
    spacing: StyleTokens.space4
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

    // Disconnecting is reversible by the control that did it, so it needs no
    // confirm step. It yields the row while the destructive action is armed:
    // once the question is "forget this?", a second button is just noise.
    PillButton {
        visible: actions.showDisconnect && !actions.confirming
        text: "Disconnect"
        interactive: actions.hovered
        onClicked: actions.disconnectRequested()
    }

    PillButton {
        visible: actions.showRemove
        iconName: actions.confirming ? "" : "window-close-symbolic"
        iconSize: StyleControl.iconSizeSm
        text: actions.confirming ? "Forget" : ""
        paddingHorizontal: actions.confirming ? StylePopover.pillPaddingH : StylePopover.iconButtonPadding
        paddingVertical: actions.confirming ? StylePopover.pillPaddingV : StylePopover.iconButtonPadding
        interactive: actions.hovered
        onClicked: {
            if (actions.confirming)
                actions.removeRequested()
            else
                actions.confirming = true
        }
    }
}
