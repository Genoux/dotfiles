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
    // Widget panels spring up from the bar; a context menu should just appear.
    property bool springReveal: true

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

    // One reversible state transition owns both directions. Qt reverses an
    // interrupted transition from its current frame, so rapid toggles cannot
    // reset opacity/scale or leave competing animations behind.
    state: active ? "shown" : "hidden"
    opacity: 0
    scale: springReveal ? StylePopover.hiddenScale : 1
    transformOrigin: Item.Bottom

    states: [
        State {
            name: "hidden"

            PropertyChanges {
                panel.opacity: 0
                panel.scale: panel.springReveal ? StylePopover.hiddenScale : 1
            }
        },
        State {
            name: "shown"

            PropertyChanges {
                panel.opacity: 1
                panel.scale: 1
            }
        }
    ]

    transitions: Transition {
        id: visibilityTransition

        from: "hidden"
        to: "shown"
        reversible: true

        OpacityAnimator {
            target: panel
            duration: StylePopover.transitionDuration
            easing.type: Easing.InOutCubic
        }

        ScaleAnimator {
            target: panel
            duration: StylePopover.transitionDuration
            easing.type: Easing.InOutCubic
        }

        onRunningChanged: {
            if (!running && panel.state === "hidden")
                panel.dismissFinished();
        }
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
