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

    default property alias content: contentLayer.data
    readonly property int chromePadding: StylePopover.padding

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
    implicitHeight: Math.max(StylePopover.minHeight, contentHeight) + chromePadding * 2
    width: implicitWidth
    height: implicitHeight

    opacity: displaying ? 1 : 0
    enabled: active
    transformOrigin: Item.Bottom

    // The pulse acknowledges the panel changing shape. A tab or month change
    // that leaves it exactly the same size has nothing to acknowledge, and a 1%
    // scale on unchanged chrome reads as a wobble rather than a transition — so
    // this follows the resize instead of being fired by hand at each call site,
    // which could not know whether the new content was the same size.
    function pulseOnResize() {
        if (!active || !displaying || panelMotion.running || panelExit.running)
            return;
        scale = StylePopover.panelStartScale;
        panelMotion.restart();
    }

    onImplicitWidthChanged: pulseOnResize()
    onImplicitHeightChanged: pulseOnResize()

    function updateVisibility() {
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
        anchors.fill: surface
        source: surface
        horizontalOffset: 0
        verticalOffset: 0
        radius: StylePopover.shadowRadius
        samples: StylePopover.shadowSamples
        color: StyleOverlay.shadow
        transparentBorder: true
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: StyleTokens.radiusMd
        color: StyleOverlay.surface
        border.width: StyleTokens.borderWidth
        border.color: StyleOverlay.surfaceBorder
    }

    Item {
        id: contentLayer

        // Implicit size flows child → panel; actual size flows panel → child.
        // Do not anchors.fill here — that is the childrenRect binding loop.
        x: chromePadding
        y: chromePadding
        width: parent.width - chromePadding * 2
        height: parent.height - chromePadding * 2


    }

}
