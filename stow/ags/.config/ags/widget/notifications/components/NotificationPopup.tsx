import { bind, Variable } from "astal"
import { Astal, Gdk, App } from "astal/gtk3"
import Notifd from "gi://AstalNotifd"
import Notification from "./Notification"
import { filterPopupNotifications } from "../Service"

const notifications = Notifd.get_default()
const dismissedPopups = Variable<number[]>([]) // Track dismissed popup notifications

// Track when AGS started to only show new notifications in popup
const agsStartTime = Date.now() / 1000

// Track timeouts for auto-hide
const autoHideTimeouts = new Map<number, any>()

// Cleanup old timeouts to prevent memory accumulation
function cleanupOldTimeouts() {
    const currentNotifications = new Set(notifications.get_notifications().map(n => n.id))
    const dismissedIds = new Set(dismissedPopups.get())
    
    for (const [notifId, timeoutId] of autoHideTimeouts.entries()) {
        // Remove timeouts for notifications that no longer exist or are dismissed
        if (!currentNotifications.has(notifId) || dismissedIds.has(notifId)) {
            clearTimeout(timeoutId)
            autoHideTimeouts.delete(notifId)
        }
    }
}

// Function to dismiss a popup notification
export function dismissPopupNotification(notifId: number) {
    const current = dismissedPopups.get()
    if (!current.includes(notifId)) {
        dismissedPopups.set([...current, notifId])
    }
    
    // Clear the auto-hide timeout for this notification
    if (autoHideTimeouts.has(notifId)) {
        clearTimeout(autoHideTimeouts.get(notifId))
        autoHideTimeouts.delete(notifId)
    }
}

// Function to dismiss all popup notifications
export function dismissAllPopups() {
    const current = visiblePopupNotifications.get()
    const dismissed = dismissedPopups.get()
    const newDismissed = [...dismissed]
    
    current.forEach(notif => {
        if (!newDismissed.includes(notif.id)) {
            newDismissed.push(notif.id)
        }
        
        // Clear any existing timeout
        if (autoHideTimeouts.has(notif.id)) {
            clearTimeout(autoHideTimeouts.get(notif.id))
            autoHideTimeouts.delete(notif.id)
        }
    })
    
    dismissedPopups.set(newDismissed)
}

// Function to schedule auto-hide for a notification
function scheduleAutoHide(notifId: number) {
    // Don't schedule if already dismissed
    if (dismissedPopups.get().includes(notifId)) {
        return
    }
    
    // Clear existing timeout for this notification
    if (autoHideTimeouts.has(notifId)) {
        clearTimeout(autoHideTimeouts.get(notifId))
    }
    
    // Set new timeout for 5 seconds
    const timeoutId = setTimeout(() => {
        dismissPopupNotification(notifId)
    }, 5000)
    
    autoHideTimeouts.set(notifId, timeoutId)
}

// Combine notifications and dismissed list reactively
const visiblePopupNotifications = Variable.derive([
    bind(notifications, "notifications"),
    dismissedPopups
], (notifs, dismissed) => {
    // Clean up old timeouts first to prevent memory accumulation
    cleanupOldTimeouts()
    
    const visible = filterPopupNotifications(notifs) // Filter out completely ignored apps
        .filter(notif => notif.time > agsStartTime) // Only show notifications that arrived after AGS started
        .filter(notif => !dismissed.includes(notif.id)) // Hide dismissed popups
        .sort((a: any, b: any) => b.time - a.time) // Sort by time, newest first
        .slice(0, 10)
    
    // Schedule auto-hide for new notifications
    visible.forEach(notif => {
        if (!autoHideTimeouts.has(notif.id)) {
            scheduleAutoHide(notif.id)
        }
    })
    
    return visible
})

// Periodic cleanup to ensure no memory leaks
const cleanupInterval = setInterval(() => {
    cleanupOldTimeouts()
}, 60000) // Clean up every minute

// Cleanup is handled automatically via periodic cleanup and timeout management

// Simple notification popup for floating notifications
export default function NotificationPopup(gdkmonitor: Gdk.Monitor) {
    return (
        <window
            name="NotificationPopup"
            className="NotificationPopup"
            gdkmonitor={gdkmonitor}
            anchor={Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
            keymode={Astal.Keymode.NONE}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            application={App}
            marginRight={8}
            marginBottom={4}
        >
            <box className="notification-popup-container" vertical spacing={8}>
                {bind(visiblePopupNotifications).as(notifs => 
                    notifs.map(notif => (
                        <Notification notification={notif} isInCenter={false} />
                    ))
                )}
            </box>
        </window>
    )
} 