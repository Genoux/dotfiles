// One floating surface at the bottom of the screen that is the time when idle,
// the time plus what is live when something is, and every panel when clicked.

import Qt5Compat.GraphicalEffects
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services as Services

// The window is sized for the largest expanded state and is otherwise empty;
// `mask` confines input to the surface, so the slack never swallows a click.
PanelWindow {
    id: root

    property bool expanded: false
    property string pageId: "home"
    property var motion: StyleIsland.closeMotion
    readonly property bool wantsKeyboard: expanded && !!expandedLoader.item && expandedLoader.item.wantsKeyboard

    // The motion set is chosen before `expanded` flips; see StyleIsland.
    function open(targetPageId = "home") {
        motion = expanded ? StyleIsland.restingMotion : StyleIsland.openMotion;
        pageId = targetPageId;
        expanded = true;
    }

    function collapse() {
        motion = StyleIsland.closeMotion;
        expanded = false;
    }

    function collapseNow() {
        motion = StyleIsland.instantMotion;
        expanded = false;
    }

    function toggleOn(targetPageId) {
        if (expanded && pageId === targetPageId)
            collapse();
        else
            open(targetPageId);
    }

    color: StyleTokens.transparent
    exclusionMode: Services.ShellLayout.island ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: StyleIsland.reservedHeight
    implicitHeight: Math.min(StyleIsland.expandedMaxHeight + StyleIsland.edgeMargin + StyleIsland.shadowMargin, screen ? screen.height : Number.MAX_VALUE)
    // Spans the screen and is masked to the surface, so the island can sit at
    // any alignment without the window moving, and the edge it reserves is the
    // one it is anchored to.
    anchors.left: true
    anchors.right: true
    anchors.top: StyleIsland.atTop
    anchors.bottom: !StyleIsland.atTop
    // Same namespace as bar popovers on purpose: Hyprland's layer rule for it
    // blurs the surface and skips the open/close animation, which would fight
    // the morph. A namespace of its own would need an identical rule added to
    // windowrules.lua for no behavioural difference.
    WlrLayershell.namespace: "quickshell-popover"
    // Only a page with a text field takes the keyboard; a display page leaves
    // typing with the focused window.
    WlrLayershell.keyboardFocus: root.wantsKeyboard ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    Connections {
        function onPageRequested(requestedPage, targetScreen, toggle) {
            if (targetScreen !== root.screen)
                return ;

            if (toggle)
                root.toggleOn(requestedPage);
            else
                root.open(requestedPage);
        }

        function onCloseRequested() {
            root.collapse();
        }

        target: Services.ShellLayout
    }

    Connections {
        function onToggleRequested(targetScreen) {
            if (targetScreen === root.screen)
                root.toggleOn("clipboard");

        }

        function onCopied() {
            if (root.expanded)
                root.collapse();

        }

        target: Services.ClipboardHistory
    }

    Connections {
        function onToggleRequested(targetScreen) {
            if (targetScreen === root.screen)
                root.toggleOn("power");

        }

        target: Services.PowerMenu
    }

    HyprlandFocusGrab {
        active: root.expanded
        windows: [root].concat(Services.PopoverCoordinator.grabPassthroughWindows)
        onCleared: root.collapse()
    }

    Item {
        id: morph

        readonly property real expandedWidth: expandedLoader.item ? expandedLoader.item.implicitWidth : StyleIsland.pageWidth
        readonly property real expandedHeight: Math.min(root.height - StyleIsland.edgeMargin - StyleIsland.shadowMargin, expandedLoader.item ? expandedLoader.item.implicitHeight : StyleIsland.compactHeight)

        anchors.top: StyleIsland.atTop ? parent.top : undefined
        anchors.bottom: StyleIsland.atTop ? undefined : parent.bottom
        anchors.topMargin: StyleIsland.edgeMargin
        anchors.bottomMargin: StyleIsland.edgeMargin
        anchors.horizontalCenter: StyleIsland.align === "center" ? parent.horizontalCenter : undefined
        anchors.left: StyleIsland.align === "left" ? parent.left : undefined
        anchors.right: StyleIsland.align === "right" ? parent.right : undefined
        anchors.leftMargin: StyleIsland.edgeMargin
        anchors.rightMargin: StyleIsland.edgeMargin
        opacity: Services.ShellLayout.islandReveal
        width: root.expanded ? expandedWidth : compact.implicitWidth
        height: root.expanded ? expandedHeight : StyleIsland.compactHeight

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
            // No outline, deliberately: the shared 1% one is below what an 8-bit
            // alpha channel can antialias, so along a curve it renders as a
            // dotted ring around the pill.

            id: surface

            anchors.fill: parent
            radius: Math.min(height / 2, StyleIsland.expandedRadius)
            color: StyleIsland.surface
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.expanded
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: Qt.PointingHandCursor
            onClicked: (mouse) => {
                if (mouse.button === Qt.MiddleButton)
                    Services.MediaPlayers.togglePlayback();
                else
                    root.open();
            }
        }

        WheelHandler {
            enabled: !root.expanded
            onWheel: (event) => {
                return Services.AudioState.stepSinkVolume(Math.sign(event.angleDelta.y));
            }
        }

        FocusScope {
            anchors.fill: parent
            clip: true
            Keys.onEscapePressed: root.collapse()

            Veil {
                anchors.centerIn: parent
                width: compact.implicitWidth
                height: compact.implicitHeight
                veil: root.expanded ? 1 : 0

                IslandCompact {
                    id: compact
                }

                Behavior on veil {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: root.motion.compactPause
                        }

                        NumberAnimation {
                            duration: root.motion.compactDuration
                            easing.type: StyleIsland.veilEasing
                        }

                    }

                }

            }

            Veil {
                id: expandedVeil

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: StyleIsland.atTop ? parent.top : undefined
                anchors.bottom: StyleIsland.atTop ? undefined : parent.bottom
                width: expandedLoader.item ? expandedLoader.item.width : 0
                height: expandedLoader.item ? expandedLoader.item.height : 0
                veil: root.expanded ? 0 : 1

                Loader {
                    id: expandedLoader

                    active: root.expanded || expandedVeil.visible

                    sourceComponent: IslandExpanded {
                        active: root.expanded
                        pageId: root.pageId
                        onPageSelected: (selectedPage) => {
                            return root.pageId = selectedPage;
                        }
                        onCollapseRequested: root.collapse()
                        onCollapseNowRequested: root.collapseNow()
                    }

                }

                Behavior on veil {
                    SequentialAnimation {
                        PauseAnimation {
                            duration: root.motion.expandedPause
                        }

                        NumberAnimation {
                            duration: root.motion.expandedDuration
                            easing.type: StyleIsland.veilEasing
                        }

                    }

                }

            }

        }

        transform: Scale {
            origin.x: morph.width / 2
            origin.y: StyleIsland.atTop ? 0 : morph.height
            xScale: StyleIsland.arrivalScale + (1 - StyleIsland.arrivalScale) * Services.ShellLayout.islandReveal
            yScale: xScale
        }

        Behavior on width {
            NumberAnimation {
                duration: root.motion.shapeDuration
                easing.type: root.motion.shapeEasing
                easing.overshoot: StyleIsland.morphOvershoot
            }

        }

        Behavior on height {
            NumberAnimation {
                duration: root.motion.shapeDuration
                easing.type: root.motion.shapeEasing
                easing.overshoot: StyleIsland.morphOvershoot
                // Only the opening overshoots; from here on the island resizes
                // with a plain ease-out, as a page change would otherwise dip.
                onRunningChanged: {
                    if (!running && root.expanded)
                        root.motion = StyleIsland.restingMotion;

                }
            }

        }

    }

    mask: Region {
        item: morph
    }

}
