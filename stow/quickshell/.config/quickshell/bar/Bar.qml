import Quickshell
import Quickshell.Wayland
import QtQuick
import qs
import qs.config
import qs.bar.widgets

PanelWindow {
    id: bar

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

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Workspaces {}
            SystemTray {
                shellWindow: bar
            }
        }

        WindowTitle {
            anchors.centerIn: parent
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            PrivacyIndicator {}
            Item {
                visible: mediaPlayer.visible
                width: 6
                height: 1
            }
            MediaPlayer {
                id: mediaPlayer
            }
            Item {
                visible: mediaPlayer.visible
                width: 6
                height: 1
            }
            VolumeButton {}
            NetworkButton {}
            BluetoothButton {}
            ScreenRecordButton {}
            KeyboardButton {}
            Battery {}
            Weather {}
            SystemTemp {}
            Clock {}
            SystemInfoButton {}
            SystemMenuButton {}
            SystemDotfilesButton {}
        }
    }
}
