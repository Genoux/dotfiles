import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.bar.widgets as Widgets
import qs.config

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
            spacing: 6

            Widgets.Workspaces {
                Layout.alignment: Qt.AlignVCenter
                hyprMonitor: bar.hyprMonitor
            }

            Widgets.SystemTray {
                Layout.alignment: Qt.AlignVCenter
            }

        }

        Widgets.WindowTitle {
            id: windowTitle

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            hyprMonitor: bar.hyprMonitor
        }

        RowLayout {
            id: rightRow

            z: 1
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Widgets.PrivacyIndicator {
                Layout.alignment: Qt.AlignVCenter
                barWindow: bar
            }

            Widgets.MediaPlayer {
                id: mediaPlayer

                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: mediaPlayer.visible ? 2 : 0
                Layout.rightMargin: mediaPlayer.visible ? 2 : 0
            }

            RowLayout {
                spacing: 4
                Layout.rightMargin: 0

                Widgets.Volume {
                    Layout.alignment: Qt.AlignVCenter
                }

                Widgets.Network {
                    Layout.alignment: Qt.AlignVCenter
                }

                Widgets.Bluetooth {
                    Layout.alignment: Qt.AlignVCenter
                }

                Widgets.ScreenRecord {
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

            Widgets.Weather {
                Layout.alignment: Qt.AlignVCenter
            }

            Widgets.Temperature {
                Layout.alignment: Qt.AlignVCenter
            }

            Widgets.Clock {
                Layout.alignment: Qt.AlignVCenter
            }

            Widgets.Info {
                Layout.alignment: Qt.AlignVCenter
            }

            Widgets.Menu {
                Layout.alignment: Qt.AlignVCenter
                screen: bar.screen
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
