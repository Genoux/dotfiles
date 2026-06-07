import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.bar.widgets

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

            Workspaces {
                Layout.alignment: Qt.AlignVCenter
                hyprMonitor: bar.hyprMonitor
            }

            SystemTray {
                Layout.alignment: Qt.AlignVCenter
                shellWindow: bar
            }
        }

        WindowTitle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            hyprMonitor: bar.hyprMonitor
        }

        RowLayout {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            PrivacyIndicator {
                Layout.alignment: Qt.AlignVCenter
            }

            MediaPlayer {
                id: mediaPlayer
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: mediaPlayer.visible ? 2 : 0
                Layout.rightMargin: mediaPlayer.visible ? 2 : 0
            }

            VolumeButton {
                Layout.alignment: Qt.AlignVCenter
            }
            NetworkButton {
                Layout.alignment: Qt.AlignVCenter
            }
            BluetoothButton {
                Layout.alignment: Qt.AlignVCenter
            }
            ScreenRecordButton {
                Layout.alignment: Qt.AlignVCenter
            }
            KeyboardButton {
                Layout.alignment: Qt.AlignVCenter
            }
            Battery {
                Layout.alignment: Qt.AlignVCenter
            }
            Weather {
                Layout.alignment: Qt.AlignVCenter
            }
            SystemTemp {
                Layout.alignment: Qt.AlignVCenter
            }
            Clock {
                Layout.alignment: Qt.AlignVCenter
            }
            SystemInfoButton {
                Layout.alignment: Qt.AlignVCenter
            }
            SystemMenuButton {
                Layout.alignment: Qt.AlignVCenter
            }
            SystemDotfilesButton {
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
