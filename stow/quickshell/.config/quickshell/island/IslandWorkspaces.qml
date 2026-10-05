import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs
import qs.components
import qs.config
import qs.services

// The monitor's workspaces as quiet dots on their own small island. Pointed at,
// each dot becomes the app it holds, and a click switches to it.
Rectangle {
    id: root

    required property var hyprMonitor

    // Hyprland lists workspaces in creation order, not by number.
    readonly property var workspaces: Hyprland.workspaces.values
        .filter((workspace) => workspace.id > 0 && workspace.monitor === hyprMonitor)
        .sort((first, second) => first.id - second.id)
    readonly property int activeId: hyprMonitor?.activeWorkspace?.id ?? 0
    property bool open: false
    // The one clock for opening and closing. Every size, fade and scale below
    // is read off it, rather than each easing on its own: separate animations
    // of different lengths drifted apart in their tails and read as a stutter.
    property real reveal: open ? 1 : 0
    // Whole pixels, so nothing creeps across a pixel boundary in the tail.
    readonly property int paddingH: Math.round(mix(StyleIsland.workspacePaddingH, StyleIsland.workspaceOpenPaddingH, reveal))

    function mix(from, to, progress) {
        return from + (to - from) * progress;
    }

    Behavior on reveal {
        NumberAnimation {
            duration: StyleIsland.workspaceRevealDuration
            easing.type: StyleTokens.easeStandard
        }
    }

    implicitWidth: dots.implicitWidth + paddingH * 2
    implicitHeight: StyleIsland.compactHeight
    width: implicitWidth
    height: implicitHeight
    radius: height / 2
    color: StyleIsland.surface

    Timer {
        id: revealDelay

        interval: StyleTokens.motionHoverDelay
        onTriggered: root.open = true
    }

    // Passive, so it stays hovered over the slots' own click areas.
    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                revealDelay.restart();
            } else {
                revealDelay.stop();
                root.open = false;
            }
        }
    }

    // Gone the moment the pill starts closing: left to its grace, the fill
    // rode the closing chips over into the island.
    SlidingHighlight {
        run: dots
        visible: root.open && opacity > 0
    }

    Row {
        id: dots

        anchors.centerIn: parent

        // Keyed on the count, not the list: a fresh array per change would
        // rebuild every slot, and nothing could animate between states.
        Repeater {
            model: root.workspaces.length

            Item {
                id: slot

                required property int index

                readonly property var workspace: root.workspaces[index]
                readonly property bool current: !!workspace && workspace.id === root.activeId
                readonly property var windows: WorkspaceApps.windowsOf(workspace)
                readonly property int overflowCount: Math.max(0, windows.length - StyleWorkspace.inlineMaxIcons)
                readonly property bool hasApps: windows.length > 0
                readonly property real appReveal: hasApps ? root.reveal : 0

                // The gap belongs to the hit area, so a click between two
                // slots still lands on one of them.
                width: Math.round(root.mix(dot.width + StyleIsland.workspaceDotSpacing, (hasApps ? chip.width : dot.width) + StyleIsland.workspaceChipGap, root.reveal))
                height: root.height

                Rectangle {
                    id: dot

                    anchors.centerIn: parent
                    width: slot.current ? StyleIsland.workspaceDotActiveWidth : StyleIsland.workspaceDotSize
                    height: StyleIsland.workspaceDotSize
                    radius: height / 2
                    color: slot.current ? Colors.base06 : Colors.base04
                    // Out in the first half of the reveal, so dot and icon never
                    // sit on top of each other at half strength.
                    opacity: (slot.current ? 1 : StyleIsland.workspaceDotIdleOpacity) * Math.max(0, 1 - slot.appReveal * 2)

                    Behavior on width {
                        NumberAnimation {
                            duration: StyleIsland.workspaceRevealDuration
                            easing.type: StyleTokens.easeStandard
                        }
                    }
                }

                // The current workspace keeps its own fill, so it stays out
                // of the travelling one.
                Rectangle {
                    id: chip

                    readonly property bool hovered: hit.containsMouse && root.open && slot.hasApps && !slot.current

                    anchors.centerIn: parent
                    // Several apps widen the chip rather than shrink the
                    // icons; the side air matches the air above and below.
                    width: Math.max(StyleIsland.workspaceChipSize, apps.implicitWidth + StyleIsland.workspaceChipPadding * 2)
                    height: StyleIsland.workspaceChipSize
                    radius: StyleIsland.workspaceChipRadius
                    color: slot.current ? StyleTokens.alphaActive : StyleTokens.transparent
                    opacity: slot.appReveal
                    scale: root.mix(StyleIsland.veilScale, 1, slot.appReveal)

                    Row {
                        id: apps

                        anchors.centerIn: parent
                        spacing: StyleWorkspace.inlineIconSpacing

                        Repeater {
                            model: ScriptModel {
                                values: slot.windows.slice(0, StyleWorkspace.inlineMaxIcons)
                            }

                            IconImage {
                                required property var modelData

                                implicitSize: StyleIsland.workspaceIconSize
                                source: WorkspaceApps.iconFor(modelData)
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: slot.overflowCount > 0
                            text: `+${slot.overflowCount}`
                            color: Colors.base04
                            font.family: StyleTokens.fontSans
                            font.pixelSize: StyleTokens.fontSizeXs
                        }
                    }
                }

                MouseArea {
                    id: hit

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: ShellActions.switchWorkspace(slot.workspace)
                }
            }
        }
    }
}
