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
            // Transparent beneath LockSurface so its wallpaper-backed scene can
            // fade directly into the live desktop on unlock.
            color: "transparent"

            LockSurface {
                anchors.fill: parent
                context: lockContext
            }
        }
    }
}
