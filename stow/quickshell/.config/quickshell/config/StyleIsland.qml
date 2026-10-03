import QtQuick
import Quickshell
import qs
pragma Singleton

// The experimental island: one floating surface that morphs between a compact
// pill, live-activity widths, and an expanded panel. Everything here is the
// island's own vocabulary; type, spacing and radii still come from StyleTokens.
Singleton {
    // Spacing. One value sets the air of the whole island: the page sides, the
    // gap above a page's first fill and under its last, a list's inset and a
    // grid's. It is the popovers' own `contentPaddingH`, so a bar popover and an
    // island page can never drift apart; raise that and everything here follows.
    // Half of it is the margin of anything that hugs the island's edge: the dock
    // track and the launcher.
    readonly property int padding: StylePopover.contentPaddingH
    readonly property int edgeInset: padding / 2
    // Anything carrying a fill (a list row, a tile, a segment track, the dock's
    // track, the launcher's field) sits on the dock's own inset, and the gap
    // between fills and above and below them is the same distance, so every
    // fill is the same distance from every edge and from its neighbour. The
    // text inside is offset to land on `padding`, under the page's titles.
    readonly property int fillInset: edgeInset
    readonly property int fillPaddingTop: edgeInset
    // The same distance again between the last content and the dock's track, on
    // every page: the track's own inset already supplies `footerInset` of it.
    readonly property int dockGap: edgeInset
    // Compact pill
    readonly property int compactHeight: 34
    readonly property int compactPaddingH: StyleTokens.space12
    readonly property int compactSpacing: StyleTokens.space8
    readonly property int activityArtSize: 20
    readonly property int activityArtRadius: StyleTokens.radiusXs
    // Placement. Change these two to move the island: `edge` is "bottom" or
    // "top", `align` is "left", "center" or "right". The surface floats off the
    // screen edge by the bar's own margin, and windows are held clear of it by a
    // spacing step beyond that.
    readonly property string edge: "bottom"
    readonly property string align: "center"
    readonly property bool atTop: edge === "top"
    readonly property int edgeMargin: StyleBar.margin
    readonly property int reservedHeight: edgeMargin + compactHeight + StyleTokens.space4
    // The wide bar: the island across the screen, with no glass, at the pill's
    // height. One height keeps one exclusive zone: a different one made
    // Hyprland re-tile every window on the switch, late and on its own timing.
    readonly property int wideInset: 0
    readonly property int wideHeight: compactHeight
    // One gap between every widget in the bar, the media player and the clock
    // included.
    readonly property int wideSpacing: StyleTokens.space6
    // The layer window must contain the largest expanded state plus its
    // shadow; input outside the surface is masked away, so the slack is inert.
    readonly property int shadowMargin: StyleOverlay.shadowBlur + StyleOverlay.shadowOffset
    readonly property int expandedMaxHeight: 900
    // The radius follows the surface's height up to this cap, so the morph
    // from pill to panel never snaps.
    readonly property int expandedRadius: StyleTokens.radiusXl
    // Nearly solid, like the Dynamic Island: as see-through glass it took on
    // the light of whatever window sat behind it. Darker than the palette's
    // darkest surface, toward the Dynamic Island's black, but still the
    // palette's hue so it follows the wallpaper, and translucent enough that a
    // blur of what is behind reads through it.
    readonly property real surfaceDarkening: 0
    readonly property real surfaceOpacity: 0.8
    readonly property color surface: StyleTokens.surfaceAlpha(Qt.darker(Colors.base00, surfaceDarkening), surfaceOpacity)
    // Expanded layout. The island is one width for every page, so it never
    // resizes sideways, and a page's full-width rules reach its edges.
    readonly property int pageWidth: StylePopover.panelWidth
    // Search and About want room; the footer menu keeps its own width and stays
    // centred under them.
    readonly property int wideWidth: 420
    // The footer menu: a rounded track of rounded-square tabs. The track floats off the
    // island's edge by `edgeInset`, and one gap runs through it: between tabs,
    // and from the tabs to the track's edge, so the tab size is what the width
    // leaves over.
    // Content running under the footer fades out over this stretch, measured up
    // from the island's bottom edge: it is gone by the time it reaches the track.
    // As long as the gap above the track, so a list scrolled to its end rests
    // exactly where the fade begins and its last row is whole.
    readonly property int footerFadeLength: dockGap
    readonly property int footerFadeEnd: footerHeight - footerInset
    readonly property int footerFadeStart: footerFadeEnd + footerFadeLength
    readonly property int footerTabCount: 8
    readonly property int footerInset: edgeInset
    readonly property int footerTrackPadding: StyleTokens.space8
    // Rounded down to even, like the glyph inside it, so the glyph sits on whole
    // pixels; the tabs are centred in the track and the spare width goes to its
    // ends.
    readonly property int footerTabSize: Math.floor((pageWidth - footerInset * 2 - (footerTabCount + 1) * footerTrackPadding) / footerTabCount / 2) * 2
    readonly property int footerTrackHeight: footerTabSize + footerTrackPadding * 2
    readonly property int footerHeight: footerTrackHeight + footerInset * 2
    // The air around the content of the pages built for the island. The sides
    // and top are the popovers' own inset, so the text edge is the same on every
    // page whether the island built it or reused it. Between groups the gap is
    // wider than anything inside a group, which is what reads as breathing room
    // rather than as blank space. Only pages that sit still get it: content that
    // scrolls (a reused popover's list, the launcher) runs all the way to the
    // footer.
    readonly property int pagePaddingH: padding
    // Each page owns the air above it: a header band centres its title, a page
    // without one starts its content as far from the top as from the sides.
    // The air under the last fill matches the air above the first: the
    // footer's own inset already sits between the page and its track, so the
    // page adds only what is left of `padding`.
    readonly property int pagePaddingTop: padding
    readonly property int pagePaddingBottom: dockGap - footerInset
    readonly property int footerTrackRadius: footerTabRadius + footerTrackPadding
    readonly property int footerTabRadius: StyleControl.chipRadius
    // Shape motion. A shape that changes size tenfold needs longer than the
    // 100ms a popover spends scaling one percent. Opening overshoots slightly,
    // which is what reads as a spring. Nothing else does: a page that resizes
    // an open island, or the way back to the pill, takes a plain ease-out,
    // because an overshoot on a shrinking shape is a visible dip.
    readonly property int morphDuration: 400
    readonly property int morphEasing: Easing.OutBack
    readonly property real morphOvershoot: 0.7
    readonly property int collapseDuration: 340
    readonly property int resizeDuration: 260
    readonly property int plainEasing: StyleTokens.easeStandard
    // Content motion. Content is laid out at its final size and never reflows
    // while the shape moves; it is hidden by a veil instead (opacity, blur and a
    // slight scale), so no frame ever shows it clipped by a half-grown surface.
    readonly property int blurMax: 32
    readonly property real veilScale: 0.96
    readonly property int veilEasing: StyleTokens.easeFade
    // Opening: the compact content clears fast, the expanded content arrives
    // once the shape is already most of the way there.
    readonly property int compactOutDuration: 90
    readonly property int expandInDelay: 60
    readonly property int expandInDuration: 240
    // Closing is the same motion reversed and quicker.
    readonly property int expandOutDuration: 80
    readonly property int compactInDelay: 160
    readonly property int compactInDuration: 140
    // Pill and wide bar never resize into each other: the island fades out,
    // swaps, and fades back in.
    readonly property int layoutFadeDuration: 140
    // Which of the above applies is chosen by direction. They travel together as
    // one object because the island has to pick the set *before* it flips state:
    // a Behavior that reads a binding on the very property that triggers it
    // starts before that binding has re-evaluated, and runs the previous
    // direction's timing.
    readonly property var openMotion: ({
        "shapeDuration": morphDuration,
        "shapeEasing": morphEasing,
        "compactPause": 0,
        "compactDuration": compactOutDuration,
        "expandedPause": expandInDelay,
        "expandedDuration": expandInDuration
    })
    // The open morph's timing minus its overshoot, for the island's life once
    // it has finished opening.
    readonly property var restingMotion: ({
        "shapeDuration": resizeDuration,
        "shapeEasing": plainEasing,
        "compactPause": 0,
        "compactDuration": compactOutDuration,
        "expandedPause": expandInDelay,
        "expandedDuration": expandInDuration
    })
    readonly property var closeMotion: ({
        "shapeDuration": collapseDuration,
        "shapeEasing": plainEasing,
        "compactPause": compactInDelay,
        "compactDuration": compactInDuration,
        "expandedPause": 0,
        "expandedDuration": expandOutDuration
    })
    // For a handoff to something that screenshots or records the screen: the
    // island must already be a pill by the time that starts.
    readonly property var instantMotion: ({
        "shapeDuration": 0,
        "shapeEasing": plainEasing,
        "compactPause": 0,
        "compactDuration": 0,
        "expandedPause": 0,
        "expandedDuration": 0
    })
    // A page change is one motion: the old page clears, then the new page
    // arrives while the shape resizes to it. Waiting for the resize before
    // showing it left an empty box on screen for a fifth of a second.
    readonly property int pageOutDuration: 90
    readonly property int pageInDuration: 160
    // How long a page's size must hold still before the island moves to it, and
    // the longest the island will wait for one that never does.
    readonly property int pageSizeSettle: 40
    readonly property int pageSizeLimit: 400
    // Notification: the pill opens in place into a card as wide as the toasts it
    // replaces, two body lines at most, so a burst cannot grow it into a panel.
    readonly property int alertWidth: StyleNotification.width
    // A short card is a true capsule, a tall one a rounded rect; a fixed 22 on
    // a 64px card is neither (Apple's Live Activity guidance says to pick one).
    readonly property int alertRadius: 32
    // Concentric with alertRadius: the icon, the actions and the X sit on the
    // same 14px from the edge.
    readonly property int alertPadding: 14
    readonly property int alertIconSize: 36
    readonly property int alertIconGap: StyleTokens.space12
    readonly property int alertTitleGap: StyleTokens.space2
    readonly property int alertBodyLines: 2
    readonly property int alertActionsGap: StyleTokens.space10
    readonly property int alertActionHeight: 36
    readonly property int alertActionSpacing: StyleTokens.space8
    readonly property int alertMaxActions: 3
    // The X mirrors the icon: centred on the icon's line, its edge on the same
    // inset, with a hit area larger than it looks.
    readonly property int alertDismissSize: 24
    readonly property int alertDismissHitSize: 32
    readonly property int alertDismissIconSize: 12
    readonly property int alertTrailingReserve: alertDismissSize + alertPadding + StyleTokens.space8
    // A newer notification replaces the card's content in place.
    readonly property int alertSwapOut: 90
    readonly property int alertSwapIn: 200
    readonly property int alertBlurMax: 8
    // Home page: the wallpaper as a card with the time and weather printed on
    // it. The scrim darkens only its lower half, where the text sits, so the
    // picture stays the picture.
    readonly property int heroHeight: 168
    readonly property int heroRadius: expandedRadius - fillInset
    readonly property int heroPadding: padding
    readonly property int heroImageWidth: pageWidth * 2
    readonly property color heroScrim: Qt.rgba(0, 0, 0, 0.5)
    readonly property real heroScrimStart: 0.35
    readonly property real heroDateOpacity: 0.8
    readonly property int clockLetterSpacing: -1
    readonly property int miniArtSize: 40
    readonly property int heroWeatherIconSize: 20
    // Media page
    // Laid out like the iPhone's expanded Now Playing: art and two lines of
    // text, a quiet scrubber, then bare transport glyphs where play/pause
    // stands out by size alone.
    readonly property int artSize: 56
    // As many bars as leave the title room to breathe at 320px.
    readonly property int waveformBars: 6
    readonly property int waveformBarWidth: StyleTokens.space2
    readonly property int waveformBarSpacing: StyleTokens.space2
    readonly property int waveformHeight: 12
    readonly property int artRadius: StyleTokens.radiusSm
    readonly property int mediaScrubberGap: StyleTokens.space20
    readonly property int mediaTransportGap: StyleTokens.space8
    readonly property int transportHitSize: 44
    readonly property int transportIconSize: 24
    readonly property int transportPrimaryIconSize: 32
    readonly property int transportSpacing: StyleTokens.space20
    // The playing app's badge on the art's corner, overhanging it slightly.
    readonly property int sourceBadgeSize: 22
    readonly property int sourceIconSize: 16
    readonly property int sourceBadgeOverhang: StyleTokens.space4
    readonly property real sourceBadgeHoverScale: 1.1
    // Position is published by the player only on request, so a playing track
    // is re-read on this cadence for the progress bar to move.
    readonly property int positionPollInterval: 1000
    // Every band of tiles sits inside the same 16px on each side as the page
    // around it, and its gap leaves whole-pixel columns in what remains:
    // 320 - 2 * 16 - 2 * 12 divides by three.
    readonly property int tileGridGap: edgeInset
}
