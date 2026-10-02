import QtQuick
import Quickshell
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
    // The layer window must contain the largest expanded state plus its
    // shadow; input outside the surface is masked away, so the slack is inert.
    readonly property int shadowMargin: StylePopover.shadowRadius + StyleTokens.space8
    readonly property int expandedMaxHeight: 900
    // Softer than the 12px panel radius because this surface is a pill first;
    // the radius follows its height up to this cap, so the morph never snaps.
    readonly property int expandedRadius: StyleTokens.space20 + StyleTokens.space4
    // Denser than a bar popover's glass, but still see-through: the island is
    // tall enough to span two windows, and at the shared 30% a bright one behind
    // it washes the text out into a grey gradient.
    readonly property color surface: Qt.rgba(8 / 255, 8 / 255, 8 / 255, 0.55)
    // Expanded layout. The island is one width for every page, so it never
    // resizes sideways, and a page's full-width rules reach its edges.
    readonly property int pageWidth: StylePopover.panelWidth
    // Search and About want room; the footer menu keeps its own width and stays
    // centred under them.
    readonly property int wideWidth: 420
    // The footer menu: a track of square tabs. The track floats off the island's
    // edge by `edgeInset`, and one gap
    // runs through it: between tabs, and from the tabs to the track's edge, so
    // the tab size is what the width leaves over. Corner radii are concentric:
    // each shape's radius is its parent's less the gap between them, so the
    // curves stay parallel all the way round.
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
    readonly property int footerTabSize: (pageWidth - footerInset * 2 - (footerTabCount + 1) * footerTrackPadding) / footerTabCount
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
    readonly property int pageSpacing: StyleTokens.space20 + StyleTokens.space4
    // One vertical system for every page. The island puts `pageInsetTop` above
    // whatever page it shows, and a page starts `padding` in from there, the way
    // a popover's header band does. The air under the last fill matches the air
    // above the first: the footer's own inset already sits between the page and
    // its track, so the page adds only what is left of `padding`.
    readonly property int pageInsetTop: StyleTokens.space8
    readonly property int pagePaddingTop: padding
    readonly property int pagePaddingBottom: dockGap - footerInset
    readonly property int footerTrackRadius: expandedRadius - footerInset
    readonly property int footerTabRadius: footerTrackRadius - footerTrackPadding
    // Shape motion. A shape that changes size tenfold needs longer than the
    // 100ms a popover spends scaling one percent. Opening overshoots slightly,
    // which is what reads as a spring. Nothing else does: a page that resizes
    // an open island, or the way back to the pill, takes a plain ease-out,
    // because an overshoot on a shrinking shape is a visible dip.
    readonly property int morphDuration: 340
    readonly property int morphEasing: Easing.OutBack
    readonly property real morphOvershoot: 0.7
    readonly property int collapseDuration: 220
    readonly property int resizeDuration: 260
    // Bar to island hand-over. One progress runs the whole switch; the bar's
    // right side finishes leaving before `islandEntryStart` is far enough in
    // for the pill to arrive, so the two overlap briefly rather than cut.
    readonly property int handoverDuration: 380
    readonly property real barExitShare: 0.55
    readonly property real islandEntryStart: 0.35
    readonly property int handoverSlide: StyleTokens.space8
    readonly property real arrivalScale: 0.9
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
    readonly property int expandInDelay: 110
    readonly property int expandInDuration: 200
    // Closing is the same motion reversed and quicker.
    readonly property int expandOutDuration: 80
    readonly property int compactInDelay: 120
    readonly property int compactInDuration: 140
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
    // A page change is one motion: the old page clears, the shape resizes, the
    // new page arrives. The settle delay is how long the resize runs before the
    // new page starts to appear.
    readonly property int pageOutDuration: 90
    readonly property int pageSettleDelay: 140
    readonly property int pageInDuration: 160
    // How long a page's size must hold still before the island moves to it, and
    // the longest the island will wait for one that never does.
    readonly property int pageSizeSettle: 80
    readonly property int pageSizeLimit: 400
    // Home page
    readonly property int clockSize: StyleTokens.fontSizeXl
    readonly property int miniArtSize: 40
    // Media page
    readonly property int artSize: 64
    // 22% of the art's edge, the proportion of an app icon's corner, so the
    // tile reads as the album cover it is and not as a card.
    readonly property int artRadius: 14
    readonly property int transportIconSize: 26
    readonly property int sourceChevronSize: 12
    // Position is published by the player only on request, so a playing track
    // is re-read on this cadence for the progress bar to move.
    readonly property int positionPollInterval: 1000
    // Every band of tiles sits inside the same 16px on each side as the page
    // around it, and its gap leaves whole-pixel columns in what remains:
    // 320 - 2 * 16 - 2 * 12 divides by three. A single row of five (Power) has no
    // gap, because its captions need the width.
    readonly property int tileGridGap: edgeInset
}
