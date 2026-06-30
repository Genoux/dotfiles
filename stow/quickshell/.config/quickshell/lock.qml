//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.lock

ShellRoot {
    LockContext {
        id: lockContext

        // Wait for the fade-out to finish before releasing the lock. Quitting
        // immediately would drop the session-lock surface mid-animation.
        onUnlocked: unlockTimer.start()
    }

    Timer {
        id: unlockTimer

        interval: StyleLock.fadeOutDuration + 50
        onTriggered: {
            lock.locked = false
            Qt.quit()
        }
    }

    WlSessionLock {
        id: lock

        locked: true

        WlSessionLockSurface {
            // Transparent so Hyprland composites the live desktop behind the
            // lock UI, letting the opacity fade read against the real desktop.
            color: "transparent"

            LockSurface {
                anchors.fill: parent
                context: lockContext
            }
        }
    }
}
