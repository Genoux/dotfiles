import QtQuick
import qs
import qs.config

// Rounded control for a panel's primary toggle — the calendar's Today jump,
// the Bluetooth power switch. Fully round ends distinguish it from the square
// bar buttons, marking it as a control inside a surface rather than on it.
Button {
    fontSize: StyleTokens.fontSizeSm
    foreground: Colors.base05
    background: StyleTokens.alphaLight
    paddingHorizontal: StylePopover.pillPaddingH
    paddingVertical: StylePopover.pillPaddingV
    radius: height / 2
    interactive: true
}
