import { Astal } from "astal/gtk3"
import { createWindow } from "../utils"
import NotificationCenter, { NotificationCenterWidget } from "./components/NotificationCenter"
import { dismissAllPopups } from "./components/NotificationPopup"

// Configuration Constants
export const NOTIFICATION_GROUP_THRESHOLD = 2; // Group notifications when more than this number from same app

// Global state to track expanded notification groups
const expandedGroups = new Set<string>();

// Helper functions to manage expanded group state
export function isGroupExpanded(appName: string): boolean {
    return expandedGroups.has(appName);
}

export function setGroupExpanded(appName: string, expanded: boolean): void {
    if (expanded) {
        expandedGroups.add(appName);
    } else {
        expandedGroups.delete(appName);
    }
}

// Apps to ignore from count and notification center (but still show in popup)
const IGNORED_FROM_COUNT_AND_CENTER_APPS: string[] = [
    "spotify", // Note: using lowercase for case-insensitive matching
]

// Apps to ignore completely (don't show anywhere)
const COMPLETELY_IGNORED_APPS_LIST: string[] = [
]

// Helper function to check if notification should be ignored from count and center
export function shouldIgnoreFromCountAndCenter(notification: any): boolean {
    const appName = notification.app_name?.toLowerCase() || ""
    const desktopEntry = notification.desktop_entry?.toLowerCase() || ""
    
    const ignoredApps = ["spotify"] // Apps to ignore from count and notification center
    
    return ignoredApps.some(ignoredApp => 
        appName.includes(ignoredApp.toLowerCase()) || 
        desktopEntry.includes(ignoredApp.toLowerCase())
    )
}

// Helper function to check if notification should be completely ignored
export function shouldCompletelyIgnore(notification: any): boolean {
    const appName = notification.app_name?.toLowerCase() || ""
    const desktopEntry = notification.desktop_entry?.toLowerCase() || ""
    
    const completelyIgnoredApps: string[] = [] // Apps to ignore completely
    
    return completelyIgnoredApps.some(ignoredApp => 
        appName.includes(ignoredApp.toLowerCase()) || 
        desktopEntry.includes(ignoredApp.toLowerCase())
    )
}

// Helper function to filter notifications for notification center (excludes count+center ignored and completely ignored)
export function filterVisibleNotifications(notifications: any[]): any[] {
    return notifications.filter(notif => 
        !shouldIgnoreFromCountAndCenter(notif) && !shouldCompletelyIgnore(notif)
    )
}

// Helper function to filter notifications for popup (only excludes completely ignored)
export function filterPopupNotifications(notifications: any[]): any[] {
    return notifications.filter(notif => !shouldCompletelyIgnore(notif))
}

// Helper function to get count (excludes count+center ignored and completely ignored)
export function getCountableNotificationCount(notifications: any[]): number {
    return filterVisibleNotifications(notifications).length
}

// Helper function to group notifications by app
export function groupNotificationsByApp(notifications: any[]): { [key: string]: any[] } {
    const groups: { [key: string]: any[] } = {};
    
    notifications.forEach(notification => {
        const appName = notification.app_name || "Unknown App";
        if (!groups[appName]) {
            groups[appName] = [];
        }
        groups[appName].push(notification);
    });
    
    // Sort notifications within each group by time (newest first)
    Object.keys(groups).forEach(appName => {
        groups[appName].sort((a, b) => b.time - a.time);
    });
    
    return groups;
}

// Helper function to determine if notifications should be grouped
export function shouldGroupNotifications(notifications: any[], threshold: number = 3): boolean {
    return notifications.length > threshold;
}

// Helper function to get grouped and ungrouped notifications for rendering
export function processNotificationsForGrouping(notifications: any[], groupThreshold: number = 3): {
    groupedApps: { [key: string]: any[] };
    ungroupedNotifications: any[];
} {
    const groups = groupNotificationsByApp(notifications);
    const groupedApps: { [key: string]: any[] } = {};
    const ungroupedNotifications: any[] = [];
    
    Object.entries(groups).forEach(([appName, appNotifications]) => {
        if (shouldGroupNotifications(appNotifications, groupThreshold)) {
            groupedApps[appName] = appNotifications;
        } else {
            ungroupedNotifications.push(...appNotifications);
        }
    });
    
    // Sort ungrouped notifications by time (newest first)
    ungroupedNotifications.sort((a, b) => b.time - a.time);
    
    return { groupedApps, ungroupedNotifications };
}

// Notification Center Window
export const notificationCenter = createWindow({
    name: "notification-center",
    className: "notification-center-window",
    content: NotificationCenter({ showCloseButton: true }),
    anchor: Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT | Astal.WindowAnchor.BOTTOM,
    autoClose: true,
})

// Subscribe to visibility changes to dismiss popups when center opens
notificationCenter.isVisible.subscribe((visible) => {
    if (visible) {
        // Dismiss all popup notifications when notification center opens
        dismissAllPopups()
    }
})

// Helper function to check if notification center is open
export function isNotificationCenterOpen(): boolean {
    return notificationCenter.isVisible.get()
} 