// One floating surface that is the time when idle, the time plus what is live
// when something is, a notification when one arrives, and every panel when
// clicked.

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import Quickshell.Wayland
import Quickshell.Widgets
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
    // The shape the island is laid out in. It trails `wide`: the switch fades
    // the island out, swaps the layout while nothing is drawn, and fades it
    // back in, so no frame shows one shape resizing into the other.
    property bool wideLayout: Services.ShellLayout.wide
    property real presence: 1
    readonly property var hyprMonitor: Hyprland.monitorFor(screen)
    property string pageId: "home"
    property var motion: StyleIsland.closeMotion
    // The notification the pill has opened into. Set by syncAlert rather than
    // bound, so the motion is chosen before the shape starts moving.
    property var alertNotification: null
    readonly property bool alerting: alertNotification !== null
    // The largest corner the shape may have: a panel is a rounded rect, a pill
    // or a notification a capsule. The cap eases between the two, so the radius
    // follows the animated height rather than lagging it through a Behavior.
    property real radiusCap: expanded ? StyleIsland.expandedRadius : StyleIsland.alertRadius

    Behavior on radiusCap {
        SequentialAnimation {
            PauseAnimation {
                duration: root.motion.shapePause
            }

            NumberAnimation {
                duration: StyleIsland.resizeDuration
                easing.type: StyleIsland.plainEasing
            }
        }
    }
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

    // The newest notification, while the island is a resting pill on the screen
    // it arrived on. An open panel is not interrupted; what arrived meanwhile
    // shows once it closes.
    function syncAlert() {
        const notifications = Services.Notifications.notifications;
        const next = Services.ShellLayout.islandAlerts && !expanded && Services.Notifications.screen === screen && notifications.length > 0
            ? notifications[notifications.length - 1]
            : null;
        if (next === alertNotification)
            return;

        if (!expanded)
            motion = next ? (alerting ? StyleIsland.restingMotion : StyleIsland.openMotion) : StyleIsland.closeMotion;
        alertNotification = next;
    }

    function toggleOn(targetPageId) {
        if (expanded && pageId === targetPageId)
            collapse();
        else
            open(targetPageId);
    }

    onExpandedChanged: syncAlert()

    Connections {
        function onNotificationsChanged() {
            root.syncAlert();
        }

        target: Services.Notifications
    }

    Connections {
        function onIslandAlertsChanged() {
            root.syncAlert();
        }

        target: Services.ShellLayout
    }

    onWideChanged: layoutSwap.restart()
    // Breaks the initial binding without changing the value. Left live, it
    // follows ShellLayout a hop ahead of onWideChanged and swaps the layout
    // before the island has faded out.
    Component.onCompleted: wideLayout = wide

    SequentialAnimation {
        id: layoutSwap

        NumberAnimation {
            target: root
            property: "presence"
            to: 0
            duration: StyleIsland.layoutFadeDuration
            easing.type: StyleIsland.veilEasing
        }

        // An open panel closes here too, unseen, rather than resizing into
        // the bar on screen.
        ScriptAction {
            script: {
                root.collapseNow();
                root.wideLayout = root.wide;
            }
        }

        NumberAnimation {
            target: root
            property: "presence"
            to: 1
            duration: StyleIsland.layoutFadeDuration
            easing.type: StyleIsland.veilEasing
        }

        ScriptAction {
            script: {
                if (!root.expanded && !root.alerting)
                    root.motion = StyleIsland.closeMotion;
            }
        }
    }
    color: StyleTokens.transparent
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: StyleIsland.reservedHeight
    implicitHeight: Math.min(StyleIsland.expandedMaxHeight + StyleIsland.edgeMargin + StyleIsland.shadowMargin, screen ? screen.height : Number.MAX_VALUE)
    // Spans the screen and is masked to the surface, so the island can sit at
    // any alignment without the window moving, and the edge it reserves is the
    // one it is anchored to.
    anchors.left: true
    anchors.right: true
    anchors.top: StyleIsland.atTop
    anchors.bottom: !StyleIsland.atTop
    // Its own namespace so Hyprland skips the open/close animation, which would
    // fight the morph, and blurs behind it with a cut just under its own alpha
    // (windowrules.lua).
    WlrLayershell.namespace: "quickshell-island"
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
        opacity: root.presence
        width: root.expanded ? expandedWidth : root.alerting ? alert.implicitWidth : root.wideLayout ? root.width - StyleIsland.edgeMargin * 2 : compact.implicitWidth
        height: root.expanded ? expandedHeight : root.alerting ? alert.implicitHeight : (root.wideLayout ? StyleIsland.wideHeight : StyleIsland.compactHeight)

        // The wide bar has no glass of its own.
        Rectangle {
            id: surface

            anchors.fill: parent
            visible: !root.wideLayout || root.expanded
            radius: Math.min(height / 2, root.radiusCap)
            color: StyleIsland.surface
        }

        MouseArea {
            anchors.fill: parent
            enabled: !root.expanded && !root.wide && !root.alerting
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
            enabled: !root.expanded && !root.alerting
            onWheel: (event) => {
                return Services.AudioState.stepSinkVolume(Math.sign(event.angleDelta.y));
            }
        }

        // Clips to the glass's own rounded shape, not its bounding box: mid-morph
        // the veiled content, and its blur, spilled into the corners outside the
        // curve. The wide bar has no glass and needs no rounding.
        ClippingRectangle {
            anchors.fill: parent
            radius: surface.visible ? surface.radius : 0
            color: StyleTokens.transparent

            FocusScope {
                anchors.fill: parent
                Keys.onEscapePressed: root.collapse()

                // Dismisses an open popover when the bare bar is clicked. The focus
                // grab treats the bar as inside the grab so its other buttons keep
                // working, which leaves bar clicks unable to dismiss anything.
                // Declared first so it sits below the widgets: an interactive one
                // consumes its own click. Dismissing on `clicked`, not `pressed`:
                // hiding a popover mid-press releases its grab while the pointer is
                // down, which cancels the press and swallows the click.
                MouseArea {
                    anchors.fill: parent
                    // Hidden rather than disabled: a disabled MouseArea still owns the
                    // cursor over its area, and this one covers the pill (Qt 6.11).
                    visible: root.wide
                    acceptedButtons: Qt.AllButtons
                    onClicked: Services.PopoverCoordinator.closeCurrent()
                }

                Veil {
                    id: barVeil

                    anchors.left: parent.left
                    anchors.leftMargin: StyleIsland.wideInset
                    anchors.verticalCenter: parent.verticalCenter
                    width: barLoader.item ? barLoader.item.implicitWidth : 0
                    height: barLoader.item ? barLoader.item.implicitHeight : 0
                    veil: root.wideLayout && !root.expanded ? 0 : 1

                    Loader {
                        id: barLoader

                        // Built from the moment the bar is asked for, off the main thread,
                        // so it is ready by the time the pill has gone.
                        active: root.wide || barVeil.visible
                        asynchronous: true

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

                Veil {
                    anchors.centerIn: parent
                    width: windowTitle.implicitWidth
                    height: windowTitle.implicitHeight
                    veil: barVeil.veil

                    Widgets.WindowTitle {
                        id: windowTitle

                        hyprMonitor: root.hyprMonitor
                    }
                }

                // Each widget opens its popover over its own button rather than
                // expanding the island.
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
                        asynchronous: true

                        sourceComponent: Row {
                            spacing: StyleIsland.wideSpacing

                            Widgets.MediaPlayer {
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            // One run of peers with the clock in it, so the icons and
                            // the time share a size, a rhythm and one travelling
                            // hover fill.
                            HoverRow {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: StyleIsland.wideSpacing

                                Widgets.Launcher {
                                    screen: root.screen
                                }

                                Widgets.Nebula {
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

                                Widgets.Keyboard {
                                }

                                Widgets.Battery {
                                }

                                Widgets.Clock {
                                    barWindow: root
                                }

                                Widgets.Dotfiles {
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
                    veil: root.expanded || root.wideLayout || root.alerting ? 1 : 0

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
                    id: alertVeil

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: StyleIsland.atTop ? parent.top : undefined
                    anchors.bottom: StyleIsland.atTop ? undefined : parent.bottom
                    width: alert.implicitWidth
                    height: alert.implicitHeight
                    blurMax: StyleIsland.alertBlurMax
                    veil: root.alerting ? 0 : 1

                    IslandAlert {
                        id: alert

                        notification: root.alertNotification
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

                Veil {
                    id: expandedVeil

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: StyleIsland.atTop ? parent.top : undefined
                    anchors.bottom: StyleIsland.atTop ? undefined : parent.bottom
                    width: expandedLoader.item ? expandedLoader.item.width : 0
                    // The surface's animated height, not the page's: the dock is
                    // anchored to the bottom of this, so it rides the glass edge
                    // through a resize instead of jumping to where it will end up.
                    height: morph.height
                    veil: root.expanded ? 0 : 1

                    Loader {
                        id: expandedLoader

                        height: parent.height
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
        }

        Behavior on width {
            SequentialAnimation {
                PauseAnimation {
                    duration: root.motion.shapePause
                }

                NumberAnimation {
                    duration: root.motion.shapeDuration
                    easing.type: root.motion.shapeEasing
                    easing.overshoot: StyleIsland.morphOvershoot
                }
            }

        }

        Behavior on height {
            SequentialAnimation {
                // Only the opening overshoots; from here on the island resizes
                // with a plain ease-out, as a page change would otherwise dip.
                onRunningChanged: {
                    if (!running && root.expanded)
                        root.motion = StyleIsland.restingMotion;
                }

                PauseAnimation {
                    duration: root.motion.shapePause
                }

                NumberAnimation {
                    duration: root.motion.shapeDuration
                    easing.type: root.motion.shapeEasing
                    easing.overshoot: StyleIsland.morphOvershoot
                }
            }

        }

    }

    // Placed like the recording, which rides outside it: the recording widens
    // on hover and would otherwise shove the tray. The wide bar has its own.
    // Gated on the service, not the widget's own `visible`, which reads false
    // whenever this veil is hidden and so could never bring it back.
    Veil {
        id: trayVeil

        LayoutMirroring.enabled: StyleIsland.companionsSpread || StyleIsland.align === "right"
        anchors.left: StyleIsland.companionsSpread ? parent.left : morph.right
        anchors.leftMargin: StyleIsland.companionsSpread ? StyleIsland.edgeMargin : StyleIsland.companionGap
        anchors.top: StyleIsland.atTop ? morph.top : undefined
        anchors.bottom: StyleIsland.atTop ? undefined : morph.bottom
        width: trayPill.width
        height: trayPill.height
        veil: SystemTray.items.values.length > 0 && !root.wideLayout ? 0 : 1

        Behavior on veil {
            NumberAnimation {
                duration: StyleIsland.layoutFadeDuration
                easing.type: StyleIsland.veilEasing
            }
        }

        // Inset by the same distance on every side, so the icons' hover fill
        // stays concentric with the capsule.
        Rectangle {
            id: trayPill

            width: tray.width + height - tray.height
            height: StyleIsland.compactHeight
            radius: height / 2
            color: StyleIsland.surface

            Widgets.SystemTray {
                id: tray

                anchors.centerIn: parent
                border.width: 0
                barWindow: root
            }
        }
    }

    // Laid out for the island's right flank, opening rightward; mirrored, it
    // takes the left flank, or the screen's right edge when spread, and opens
    // leftward, so it always opens away from what it is anchored to.
    // The wide bar carries the recording in its own capture button instead.
    Veil {
        id: recordingVeil

        LayoutMirroring.enabled: StyleIsland.companionsSpread || StyleIsland.align === "right"
        LayoutMirroring.childrenInherit: true
        anchors.left: trayVeil.visible ? trayVeil.right : StyleIsland.companionsSpread ? parent.left : morph.right
        anchors.leftMargin: StyleIsland.companionsSpread && !trayVeil.visible ? StyleIsland.edgeMargin : StyleIsland.companionGap
        anchors.top: StyleIsland.atTop ? morph.top : undefined
        anchors.bottom: StyleIsland.atTop ? undefined : morph.bottom
        width: recordingPill.width
        height: recordingPill.height
        veil: Services.CaptureState.recording && !root.wideLayout ? 0 : 1

        Behavior on veil {
            NumberAnimation {
                duration: StyleIsland.layoutFadeDuration
                easing.type: StyleIsland.veilEasing
            }
        }

        IslandRecording {
            id: recordingPill
        }
    }

    // The recording's mirror on the other flank, or at the screen's left edge
    // when spread. Only its placement mirrors: the dots inside must keep
    // counting up from the left. The wide bar has its own.
    // ponytail: grouped beside a left-aligned island, both companions land on
    // the right, on top of each other; stack them if that alignment is used.
    Veil {
        id: workspacesVeil

        LayoutMirroring.enabled: StyleIsland.companionsSpread || StyleIsland.align === "left"
        anchors.right: StyleIsland.companionsSpread ? parent.right : morph.left
        anchors.rightMargin: StyleIsland.companionsSpread ? StyleIsland.edgeMargin : StyleIsland.companionGap
        anchors.top: StyleIsland.atTop ? morph.top : undefined
        anchors.bottom: StyleIsland.atTop ? undefined : morph.bottom
        width: workspacesPill.width
        height: workspacesPill.height
        veil: root.wideLayout ? 1 : 0

        Behavior on veil {
            NumberAnimation {
                duration: StyleIsland.layoutFadeDuration
                easing.type: StyleIsland.veilEasing
            }
        }

        IslandWorkspaces {
            id: workspacesPill

            hyprMonitor: root.hyprMonitor
        }
    }

    mask: Region {
        item: morph

        Region {
            item: trayVeil.visible ? trayVeil : null
        }

        Region {
            item: recordingVeil.visible ? recordingVeil : null
        }

        Region {
            item: workspacesVeil.visible ? workspacesVeil : null
        }
    }

}
