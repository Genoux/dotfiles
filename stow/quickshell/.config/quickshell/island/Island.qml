// One floating surface at the bottom of the screen that is the time when idle,
// the time plus what is live when something is, and every panel when clicked.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.bar.widgets as Widgets
import qs.components
import qs.config
import qs.services as Services

// The window is sized for the largest expanded state and is otherwise empty;
// `mask` confines input to the surface, so the slack never swallows a click.
PanelWindow {
    id: root

    property bool expanded: false
    readonly property bool wide: Services.ShellLayout.wide
    readonly property var hyprMonitor: Hyprland.monitorFor(screen)
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

    onWideChanged: {
        if (!expanded)
            motion = StyleIsland.restingMotion;

    }
    color: StyleTokens.transparent
    exclusionMode: Services.ShellLayout.island ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: root.wide ? StyleIsland.wideReservedHeight : StyleIsland.reservedHeight
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
            if (targetScreen === root.screen && !root.wide)
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
            if (targetScreen === root.screen && !root.wide)
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
        width: root.expanded ? expandedWidth : (root.wide ? root.width - StyleIsland.edgeMargin * 2 : compact.implicitWidth)
        height: root.expanded ? expandedHeight : (root.wide ? StyleIsland.wideHeight : StyleIsland.compactHeight)

        Rectangle {
            // No outline and no shadow, deliberately: both antialias into a
            // soft rim along a curve, and a shadow that crosses the compositor's
            // blur threshold blurs a halo that picks up a bright window behind.

            id: surface

            anchors.fill: parent
            radius: root.wide && !root.expanded ? StyleIsland.wideRadius : Math.min(height / 2, StyleIsland.expandedRadius)
            color: root.wide && !root.expanded ? StyleIsland.wideSurface : StyleIsland.surface

            Behavior on radius {
                NumberAnimation {
                    duration: StyleIsland.resizeDuration
                    easing.type: StyleIsland.plainEasing
                }
            }

            Behavior on color {
                ColorAnimation {
                    duration: StyleIsland.resizeDuration
                    easing.type: StyleIsland.plainEasing
                }
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.expanded && !root.wide
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
                id: barVeil

                anchors.left: parent.left
                anchors.leftMargin: StyleIsland.wideInset
                anchors.verticalCenter: parent.verticalCenter
                width: barLoader.item ? barLoader.item.implicitWidth : 0
                height: barLoader.item ? barLoader.item.implicitHeight : 0
                veil: root.wide && !root.expanded ? 0 : 1

                Loader {
                    id: barLoader

                    active: root.wide || barVeil.visible

                    sourceComponent: Row {
                        spacing: StyleIsland.wideSpacing

                        Widgets.Workspaces {
                            anchors.verticalCenter: parent.verticalCenter
                            hyprMonitor: root.hyprMonitor
                        }

                        Widgets.SystemTray {
                            anchors.verticalCenter: parent.verticalCenter
                            barWindow: root
                        }
                    }
                }
            }

            // The old bar's own widgets, so each opens its popover over its
            // button the way it does there rather than expanding the island.
            Veil {
                id: controlsVeil

                anchors.right: parent.right
                anchors.rightMargin: StyleIsland.wideInset
                anchors.verticalCenter: parent.verticalCenter
                width: controlsLoader.item ? controlsLoader.item.implicitWidth : 0
                height: controlsLoader.item ? controlsLoader.item.implicitHeight : 0
                veil: barVeil.veil

                Loader {
                    id: controlsLoader

                    active: root.wide || controlsVeil.visible

                    sourceComponent: Row {
                        spacing: StyleIsland.wideSpacing

                        Widgets.MediaPlayer {
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // One run of peers with the clock in it, as in the old
                        // bar, so the icons and the time share a size, a rhythm
                        // and one travelling hover fill.
                        HoverRow {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: StyleIsland.wideSpacing

                            Widgets.Launcher {
                                screen: root.screen
                            }

                            Widgets.Volume {
                                barWindow: root
                            }

                            Widgets.Network {
                                barWindow: root
                            }

                            Widgets.Bluetooth {
                                barWindow: root
                            }

                            Widgets.Clipboard {
                                barWindow: root
                            }

                            Widgets.Capture {
                                screen: root.screen
                                barWindow: root
                            }

                            Widgets.Clock {
                                barWindow: root
                            }

                            Widgets.MoreMenu {
                                barWindow: root
                            }
                        }
                    }
                }
            }

            Veil {
                id: compactVeil

                anchors.centerIn: parent
                width: compact.implicitWidth
                height: compact.implicitHeight
                veil: root.expanded || root.wide ? 1 : 0

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
