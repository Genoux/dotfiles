//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import qs.bar
import qs.components
import qs.launcher
import qs.notifications
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

        Backdrop {
            required property var modelData

            screen: modelData
            active: Services.Launcher.visible && Services.Launcher.screen === modelData
            layerNamespace: "launcher-backdrop"
            onDismissed: Services.Launcher.close()
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

        VolumeOsdWindow {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        NotificationWindow {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        Backdrop {
            required property var modelData

            screen: modelData
            active: Services.PowerMenu.visible && Services.PowerMenu.screen === modelData
            layerNamespace: "power-menu-backdrop"
            onDismissed: Services.PowerMenu.close()
        }
    }

    Variants {
        model: Quickshell.screens

        PowerMenuWindow {
            required property var modelData
            screen: modelData
        }
    }
}
