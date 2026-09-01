//@ pragma UseQApplication

import Quickshell
import Quickshell.Io
import qs.bar
import qs.capture
import qs.components
// Loaded only when requested through the component-gallery IPC target.
import qs.debug
import qs.launcher
import qs.notifications
import qs.osd
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

    // The capture scripts own grim, slurp, and the recorder; they report back
    // here. Best-effort by design: a dead shell must not fail a capture.
    IpcHandler {
        target: "capture"

        function saved(path: string): void {
            Services.CaptureState.present(path)
        }

        function countdown(seconds: int): void {
            Services.CaptureState.showCountdown(seconds)
        }

        function delay(): int {
            return Services.CaptureState.delaySeconds
        }
    }

    IpcHandler {
        target: "components"

        function toggle(): void {
            Services.ComponentGallery.toggle()
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

        ComponentGalleryWindow {
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

        CaptureCountdownWindow {
            required property var modelData
            screen: modelData
        }
    }

    Variants {
        model: Quickshell.screens

        CapturePreviewWindow {
            required property var modelData
            screen: modelData
        }
    }
}
