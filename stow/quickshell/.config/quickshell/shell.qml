import Quickshell
import Quickshell.Io
import qs.bar
import qs.launcher
import qs.osd
import qs.power
import qs.services as Services

ShellRoot {
    IpcHandler {
        target: "launcher"

        function toggle(): void {
            Services.Launcher.toggle()
        }
    }

    IpcHandler {
        target: "powermenu"

        function toggle(): void {
            Services.PowerMenu.toggle()
        }
    }

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        LauncherWindow {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        LauncherBackdrop {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        VolumeOsdWindow {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        PowerMenuWindow {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        PowerMenuBackdrop {
            required property var modelData
            screen: modelData
        }
    }
}
