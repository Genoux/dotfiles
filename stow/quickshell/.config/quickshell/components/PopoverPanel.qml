import Qt5Compat.GraphicalEffects
import QtQuick
import qs.config

// Popover panel surface — floats above the bar with all four corners rounded.
// Uses the translucent overlay material: the Hyprland layer rule for the quickshell
// namespace sets blur_popups, so popup windows receive the same compositor blur as the bar.
Item {
    id: panel

    property bool active: false
    property bool fitContent: false
    property bool displaying: false
    // Rendered inside another surface (the island), which owns the chrome and
    // the motion: the panel keeps its content, sizing and `active` lifecycle,
    // and drops the surface, shadow, reveal scale and inset, so its rules run
    // edge to edge.
    property bool embedded: false
    // An embedded page that ends on its own bottom edge (a list that scrolls to
    // the island's footer, or a page with its own inset) opts out of the air the
    // island otherwise leaves beneath a page's last row.
    property bool flushBottom: false
    // A list that carries on beneath the island's footer menu instead of ending
    // above it. The page's height then includes the footer's, which is drawn
    // over its tail, and `listReach` is how far the list runs past its fold.
    property bool underFooter: false
    readonly property int listReach: embedded && underFooter ? StyleIsland.footerHeight : 0
    // The air above a list's first row and under its last, the same as a static
    // page keeps under its header and above the dock.
    readonly property int listStartPadding: embedded ? StyleIsland.fillPaddingTop : StylePopover.contentPaddingV
    // Exactly the stretch the fade occupies, so a list scrolled to its end rests
    // where the fade begins and its last row is never dimmed.
    readonly property int listEndPadding: embedded && underFooter
        ? StyleIsland.footerFadeEnd + StyleIsland.footerFadeLength
        : StylePopover.contentPaddingV
    // Where anything carrying a fill sits from the panel's sides: list rows, tiles
    // and segmented controls. A bar popover floats its fills just inside the
    // border; in the island they share the page's own padding, so a list is
    // inset exactly like a grid.
    readonly property int fillInset: embedded ? StyleIsland.fillInset : StylePopover.listRowInset
    // The gap inside a band of tiles, and under the control that selects them.
    readonly property int bandGap: embedded ? StyleIsland.tileGridGap : StyleTokens.space4
    readonly property int bandPaddingTop: embedded ? StyleIsland.fillPaddingTop : StylePopover.segmentBandPaddingTop
    readonly property int bandPaddingBottom: embedded ? bandGap : StylePopover.segmentBandPaddingBottom

    default property alias content: contentLayer.data
    readonly property int chromePadding: embedded ? 0 : StylePopover.padding

    signal dismissFinished()

    // Size from content children's *implicit* geometry, not childrenRect.
    // childrenRect + anchors.fill closes a binding loop (quickshell
    // size-position guide) that can drop chrome padding on the first layout.
    //
    // Take the max across children: tray menus declare QsMenuOpener before
    // the Column, so indexing children[0] would size to an empty opener.
    readonly property real contentImplicitWidth: {
        let width = 0;
        for (let i = 0; i < contentLayer.children.length; i++)
            width = Math.max(width, contentLayer.children[i].implicitWidth);
        return width;
    }
    readonly property real contentImplicitHeight: {
        let height = 0;
        for (let i = 0; i < contentLayer.children.length; i++)
            height = Math.max(height, contentLayer.children[i].implicitHeight);
        return height;
    }

    // fitContent opts out of the *width* floor, for panels that must hug their
    // content (a context menu sized to its widest entry). Prefer the child's
    // actual width when set (tray menu clamps implicitWidth); fall back to
    // implicit. The height floor still applies either way: it guards against
    // a panel that is briefly empty while its content resolves.
    readonly property real contentWidth: {
        if (!fitContent)
            return contentImplicitWidth;

        let width = 0;
        for (let i = 0; i < contentLayer.children.length; i++) {
            const child = contentLayer.children[i];
            width = Math.max(width, child.width || child.implicitWidth);
        }
        return width;
    }
    readonly property real contentHeight: contentImplicitHeight

    implicitWidth: (fitContent ? contentWidth : Math.max(StylePopover.minWidth, contentWidth)) + chromePadding * 2
    readonly property int bottomInset: embedded && !flushBottom ? StyleIsland.pagePaddingBottom : 0

    implicitHeight: Math.max(StylePopover.minHeight, contentHeight) + chromePadding * 2 + bottomInset
    width: implicitWidth
    height: implicitHeight

    opacity: embedded || displaying ? 1 : 0
    enabled: active
    transformOrigin: Item.Bottom

    // The pulse acknowledges the panel changing shape. A tab or month change
    // that leaves it exactly the same size has nothing to acknowledge, and a 1%
    // scale on unchanged chrome reads as a wobble rather than a transition — so
    // this follows the resize instead of being fired by hand at each call site,
    // which could not know whether the new content was the same size.
    function pulseOnResize() {
        if (embedded || !active || !displaying || panelMotion.running || panelExit.running)
            return;
        scale = StylePopover.panelStartScale;
        panelMotion.restart();
    }

    onImplicitWidthChanged: pulseOnResize()
    onImplicitHeightChanged: pulseOnResize()

    function updateVisibility() {
        if (embedded) {
            displaying = active;
            if (!active)
                finishDismissal();
            return;
        }

        if (active) {
            const reopening = displaying;
            panelExit.stop();
            displaying = true;
            if (!reopening) {
                scale = StylePopover.panelStartScale;
            }
            panelMotion.restart();
        } else {
            panelMotion.stop();
            if (!displaying || StylePopover.panelExitScale === 1 || StylePopover.panelExitDuration <= 0)
                Qt.callLater(finishDismissal);
            else
                panelExit.restart();
        }
    }

    function finishDismissal() {
        if (!active) {
            displaying = false;
            dismissFinished();
        }
    }

    onActiveChanged: updateVisibility()

    // A host that is torn down with the panel open (the island being switched
    // off) never sees it close, and the close handlers are what release the
    // polling and scans a panel started.
    Component.onDestruction: {
        if (embedded && active)
            active = false;
    }
    Component.onCompleted: {
        if (active && !displaying)
            updateVisibility();
    }

    NumberAnimation {
        id: panelMotion

        target: panel
        property: "scale"
        to: 1
        duration: StylePopover.panelMotionDuration
        easing.type: StylePopover.panelMotionEasing
    }

    NumberAnimation {
        id: panelExit

        target: panel
        property: "scale"
        to: StylePopover.panelExitScale
        duration: StylePopover.panelExitDuration
        easing.type: StylePopover.panelExitEasing
        onFinished: panel.finishDismissal()
    }

    DropShadow {
        visible: !panel.embedded
        anchors.fill: surface
        source: surface
        horizontalOffset: 0
        verticalOffset: StyleOverlay.shadowOffset
        radius: StyleOverlay.shadowBlur
        samples: StyleOverlay.shadowSamples
        color: StyleOverlay.shadow
        transparentBorder: true
    }

    Rectangle {
        id: surface

        visible: !panel.embedded
        anchors.fill: parent
        radius: StyleTokens.radiusXl
        color: StyleOverlay.surface
    }

    Item {
        id: contentLayer

        // Implicit size flows child → panel; actual size flows panel → child.
        // Do not anchors.fill here — that is the childrenRect binding loop.
        x: chromePadding
        y: chromePadding
        width: parent.width - chromePadding * 2
        height: parent.height - chromePadding * 2 - bottomInset


    }

}
