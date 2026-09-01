import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.bar.widgets as Widgets
import qs.components
import qs.config
import qs.services as Services

PanelWindow {
    id: bar

    readonly property var hyprMonitor: Hyprland.monitorFor(screen)

    readonly property int contentHeight: Math.max(StyleBar.estimatedContentHeight, leftRow.implicitHeight, windowTitle.implicitHeight, rightRow.implicitHeight)

    implicitHeight: contentHeight + StyleBar.topPadding + StyleBar.bottomPadding
    height: implicitHeight
    color: StyleBar.background

    anchors {
        bottom: true
        left: true
        right: true
    }

    // Dismisses an open popover when the bar itself is clicked. The focus grab
    // covers clicks outside the bar, but it deliberately treats the bar as
    // inside the grab so other bar buttons keep working — leaving bar clicks
    // unable to dismiss anything.
    //
    // Declared first so it sits *below* the widgets: an interactive widget
    // consumes its own click and handles its own popover, while empty bar space
    // and non-interactive widgets (which accept no buttons) fall through to
    // here. Dismissing on `clicked` rather than `pressed` is essential — hiding
    // a popover mid-press releases its focus grab while the pointer is still
    // down, which cancels the press and swallows the click entirely.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: Services.PopoverCoordinator.closeCurrent()
    }

    Item {
        anchors.fill: parent
        anchors.leftMargin: StyleBar.margin
        anchors.rightMargin: StyleBar.margin
        anchors.topMargin: StyleBar.topPadding
        anchors.bottomMargin: StyleBar.bottomPadding

        RowLayout {
            id: leftRow

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: StyleTokens.space6

            Widgets.Workspaces {
                Layout.alignment: Qt.AlignVCenter
                hyprMonitor: bar.hyprMonitor
            }

            Widgets.SystemTray {
                Layout.alignment: Qt.AlignVCenter
                barWindow: bar
            }

        }

        Widgets.WindowTitle {
            id: windowTitle

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            hyprMonitor: bar.hyprMonitor
            availableWidth: Math.max(0, rightRow.x - StyleTokens.space6 - windowTitle.x)
        }

        RowLayout {
            id: rightRow

            z: 1
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: StyleTokens.space1

            Widgets.PrivacyIndicator {
                Layout.alignment: Qt.AlignVCenter
                barWindow: bar
            }

            Widgets.MediaPlayer {
                id: mediaPlayer

                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: mediaPlayer.visible ? StyleTokens.space2 : 0
                Layout.rightMargin: mediaPlayer.visible ? StyleTokens.space2 : 0
            }

            RowLayout {
                spacing: StyleTokens.space1
                Layout.rightMargin: 0

                Widgets.Volume {
                    Layout.alignment: Qt.AlignVCenter
                    barWindow: bar
                }

                Widgets.Network {
                    Layout.alignment: Qt.AlignVCenter
                    barWindow: bar
                }

                Widgets.Bluetooth {
                    Layout.alignment: Qt.AlignVCenter
                    barWindow: bar
                }

                Widgets.Capture {
                    Layout.alignment: Qt.AlignVCenter
                    screen: bar.screen
                    barWindow: bar
                }

                Widgets.Keyboard {
                    Layout.alignment: Qt.AlignVCenter
                }

                Widgets.Battery {
                    Layout.alignment: Qt.AlignVCenter
                }

            }

            RowLayout {
                spacing: StyleTokens.space4

                Widgets.Weather {
                    barWindow: bar
                }

                Widgets.Temperature {
                    barWindow: bar
                }

                Widgets.Clock {
                    barWindow: bar
                }

            }

            Widgets.Info {
                Layout.alignment: Qt.AlignVCenter
            }

            // Keep the development surface available without occupying a keybind.
            Widgets.ComponentGallery {
                Layout.alignment: Qt.AlignVCenter
                screen: bar.screen
            }

            Widgets.Menu {
                Layout.alignment: Qt.AlignVCenter
                barWindow: bar
            }

            Widgets.Dotfiles {
                Layout.alignment: Qt.AlignVCenter
            }

            Widgets.Launcher {
                Layout.alignment: Qt.AlignVCenter
                screen: bar.screen
            }

        }

    }

}
