pragma Singleton

import Quickshell

import QtQuick

// The single source of truth for every cross-cutting visual primitive.
//
// Domain files (StyleBar, StylePopover, StyleLauncher, ...) name *what a thing
// is* in their own vocabulary; they take *what it measures* from here. A domain
// file may only hold a raw literal when the value is genuinely unique to that
// surface and a comment says why.
Singleton {
    readonly property string fontSans: "SF Pro Text"
    readonly property string fontMono: "JetBrainsMono Nerd Font Mono"
    readonly property string fontIcon: "JetBrainsMono Nerd Font"
    readonly property string fontEmoji: "Noto Color Emoji"

    readonly property int fontSizeXl: 32
    readonly property int fontSizeLg: 16
    readonly property int fontSizeMd: 14
    readonly property int fontSizeSm: 12
    readonly property int fontSizeXs: 10
    readonly property int fontSizeMedia: 11

    readonly property int radiusXs: 4
    readonly property int radiusSm: 8
    readonly property int radiusMd: 12

    // Spacing is numeric, not t-shirt sized: a bar this dense needs ten steps,
    // and Sm/Md/Lg stops being readable past four. The step IS the pixel value,
    // so `space6` never needs a lookup to review.
    //
    // space4 is the base unit — bar chrome, button padding, panel inset. Steps
    // below it exist because bar rows are ~24px tall and 1-3px is the only room
    // there is; steps above it are the 4-multiples panels are built from.
    readonly property int space1: 1
    readonly property int space2: 2
    readonly property int space3: 3
    readonly property int space4: 4
    readonly property int space6: 6
    readonly property int space8: 8
    readonly property int space10: 10
    readonly property int space12: 12
    readonly property int space16: 16
    readonly property int space20: 20

    // Every stroke in the shell is one physical pixel. There is no second
    // border weight — depth comes from alpha, not thickness.
    readonly property int borderWidth: 1

    readonly property int pollIntervalFast: 1000
    readonly property int pollIntervalNormal: 5000
    readonly property int pollIntervalSlow: 30000

    // Three motion speeds, and only three. `Instant` is for a surface that must
    // not appear to travel (backdrops, overlay fades); `Fast` is the default for
    // state feedback on something already on screen; `Normal` is for a surface
    // entering or leaving. Anything slower reads as lag on a bar you glance at.
    readonly property int easeDurationInstant: 100
    readonly property int easeDurationFast: 150
    readonly property int easeDurationNormal: 200

    // Curves are tokens too, because the same gesture was being drawn with
    // OutCubic in one widget and InOutQuad in its neighbour.
    // Standard: anything entering, revealing, or responding to a pointer.
    // Symmetric: a fill or tint that must feel identical in and out.
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeSymmetric: Easing.InOutQuad

    readonly property color transparent: "transparent"
    // The interaction tint. One value, everywhere: hover fill, resting pill
    // fill, selected row. Its faintness is the point — the bar sits over a
    // wallpaper and a heavier tint reads as a hole punched in the panel.
    readonly property color alphaLight: Qt.rgba(1, 1, 1, 0.03)
    // The structural hairline: separators, internal borders, selected chrome.
    readonly property color alphaHairline: Qt.rgba(1, 1, 1, 0.02)
    // A bar control whose panel is OPEN. Heavier than the hover tint, because
    // hover says "you are pointing at this" and open says "this is the thing on
    // screen right now" — at equal alpha the two are indistinguishable. It holds
    // roughly 2.3x alphaLight, so move the pair together or the states merge.
    // Both are deliberately faint: the bar sits over a wallpaper, and a tint
    // heavy enough to hide it reads as a patch stuck on rather than a lit
    // control. At 0.12 the wallpaper stopped dead at the pill's edge.
    readonly property color alphaActive: Qt.rgba(1, 1, 1, 0.07)

    // Disabled is opacity, never a greyed colour — the palette is wallpaper
    // derived, so a hardcoded grey would drift out of theme on every wallpaper.
    readonly property real opacityDisabled: 0.4
    // A label that titles content rather than being content (eyebrows, captions).
    readonly property real opacityMuted: 0.6

    function surfaceAlpha(color, alpha) {
        return Qt.rgba(color.r, color.g, color.b, alpha)
    }
}
