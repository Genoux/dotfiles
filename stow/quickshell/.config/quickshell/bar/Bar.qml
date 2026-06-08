import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.bar.widgets as Widgets

PanelWindow {
    id: bar

    readonly property var hyprMonitor: Hyprland.monitorFor(screen)

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: Style.barHeight
    color: Style.transparent

    Item {
        anchors.fill: parent
        anchors.leftMargin: Style.barMargin
        anchors.rightMargin: Style.barMargin

        RowLayout {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Widgets.Launcher {
                Layout.alignment: Qt.AlignVCenter
                screen: bar.screen
            }

            Widgets.Workspaces {
                Layout.alignment: Qt.AlignVCenter
                hyprMonitor: bar.hyprMonitor
            }

            Widgets.SystemTray {
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Widgets.WindowTitle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            hyprMonitor: bar.hyprMonitor
        }

        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Widgets.PrivacyIndicator {
                Layout.alignment: Qt.AlignVCenter
            }

            Widgets.MediaPlayer {
                id: mediaPlayer
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: mediaPlayer.visible ? 2 : 0
                Layout.rightMargin: mediaPlayer.visible ? 2 : 0
            }

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
            }
            Widgets.Keyboard {
                Layout.alignment: Qt.AlignVCenter
            }
            Widgets.Battery {
                Layout.alignment: Qt.AlignVCenter
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
            }
            Widgets.Dotfiles {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
