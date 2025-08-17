import Notifd from "gi://AstalNotifd";
import { createBinding, createState } from "ags";

// Astal notifications service (guarded)
let notifd: any = null;
try {
  notifd = Notifd.get_default();
  console.log("[Notifications] Successfully connected to Notifd");
} catch (error) {
  console.error("[Notifications] Failed to connect to Notifd:", error);
}

// Live list of notifications from the daemon or empty state fallback
let __notifications: any;
if (notifd) {
  __notifications = createBinding(notifd, "notifications");
} else {
  const [list] = createState<any[]>([]);
  __notifications = list;
}
export const notifications = __notifications;

// Notification rack state - manages live notifications that stack
export const [rackNotifications, setRackNotifications] = createState<any[]>([]);
export const [centerVisible, setCenterVisible] = createState(false);

// Debug: Log initial rack state
console.log("[Notifications] Rack initialized, notifd available:", !!notifd);

// Simple timeout tracking
const BASE_DISMISS_TIME = 3000;
const NOTIFICATION_INTERVAL = 2000;
const timeouts = new Map<any, any>();
let orderCounter = 0;

// When a new notification arrives, add it to the rack
try {
  if (notifd) {
    notifd.connect("notified", (_: any, id: number, is_new: boolean) => {
      console.log("[Notifications] Notified signal - ID:", id, "is_new:", is_new);
      
      // Get the actual notification object using the ID
      const notification = notifd.get_notification(id);
      if (!notification) {
        console.warn("[Notifications] Could not get notification with ID:", id);
        return;
      }
      
      console.log("[Notifications] Got notification:", notification.summary, notification.body);
      
      // Add to rack immediately
      setRackNotifications(prev => [...prev, notification]);
      
      // Set individual timeout for this notification
      const order = orderCounter++;
      const dismissTime = BASE_DISMISS_TIME + (order * NOTIFICATION_INTERVAL);
      
      console.log("[Notifications] Will dismiss in:", dismissTime, "ms");
      
      const timeoutId = setTimeout(() => {
        console.log("[Notifications] Auto-dismissing notification:", notification.summary);
        removeFromRack(notification);
      }, dismissTime);
      
      timeouts.set(notification, timeoutId);
    });
    console.log("[Notifications] Service connected successfully");
  } else {
    console.log("[Notifications] No notifd available");
  }
} catch (error) {
  console.error("[Notifications] Failed to connect:", error);
}

function removeFromRack(notification: any) {
  console.log("[Notifications] removeFromRack called for notification");
  
  // Clear timeout
  const timeoutId = timeouts.get(notification);
  if (timeoutId) {
    clearTimeout(timeoutId);
    timeouts.delete(notification);
    console.log("[Notifications] Cleared timeout");
  }
  
  // Get current state before removal
  const currentNotifs = rackNotifications.get();
  console.log("[Notifications] Current notifications count before removal:", currentNotifs.length);
  
  // Remove from rack
  setRackNotifications(prev => {
    const filtered = prev.filter(n => n !== notification);
    console.log("[Notifications] Filtered notifications count:", filtered.length);
    console.log("[Notifications] Was notification removed?", prev.length !== filtered.length);
    
    // Reset counter when empty
    if (filtered.length === 0) {
      orderCounter = 0;
      console.log("[Notifications] All cleared, reset counter");
    }
    
    return filtered;
  });
  
  // Check state after update
  setTimeout(() => {
    const newCount = rackNotifications.get().length;
    console.log("[Notifications] State after removal:", newCount);
  }, 100);
  
  // System dismiss
  try {
    notification?.dismiss?.();
  } catch (e) {
    console.log("[Notifications] System dismiss failed");
  }
}

// Legacy popup state for backward compatibility
export const [lastPopup, setLastPopup] = createState<any | null>(null);
export const [popupVisible, setPopupVisible] = createState(false);

// Public function to dismiss notification (called from UI)
export function dismissNotification(n: any) {
  console.log("[Notifications] Manual dismiss requested");
  removeFromRack(n);
}

export function invokeDefault(n: any) {
  try { n?.activate?.(); } catch {}
}

let __centerShown = false;
export function toggleNotificationCenter() {
  __centerShown = !__centerShown;
  setCenterVisible(__centerShown);
  try { print(`[Notifications] centerVisible -> ${__centerShown}`); } catch {}
}

// Force clear all notifications (debug helper)
export function clearAllNotifications() {
  console.log("[Notifications] Force clearing all notifications");
  
  // Clear all timeouts
  timeouts.forEach((timeoutId) => {
    clearTimeout(timeoutId);
  });
  
  timeouts.clear();
  orderCounter = 0;
  setRackNotifications([]);
  
  console.log("[Notifications] All notifications cleared");
}

// Add immediate clear function to call from console
try {
  (globalThis as any).clearNotifications = clearAllNotifications;
} catch {
  // Ignore if global assignment fails
}
