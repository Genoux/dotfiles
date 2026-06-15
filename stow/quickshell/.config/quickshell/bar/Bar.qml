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

    readonly property int contentHeight: Math.max(
        StyleBar.estimatedContentHeight,
        leftRow.implicitHeight,
        windowTitle.implicitHeight,
        rightRow.implicitHeight
    )

    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: contentHeight + StyleBar.topPadding + StyleBar.bottomPadding
    height: implicitHeight
    color: StyleBar.background

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

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

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
