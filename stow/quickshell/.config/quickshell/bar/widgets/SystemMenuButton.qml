import Quickshell.Io
import qs.components
IconButton {
    interactive: true
    iconName: "system-shutdown-symbolic"
    onClicked: clickProcess.running = true

    Process {
        id: clickProcess

        command: ["walker", "--provider", "menus:system", "--nohints", "--nosearch"]
    }
}
