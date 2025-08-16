import Notifd from "gi://AstalNotifd";
import { createBinding, createState } from "ags";

// Astal notifications service (guarded)
let notifd: any = null;
try {
  notifd = Notifd.get_default();
} catch {}

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

// Auto-dismiss timeout per notification
const AUTO_DISMISS_TIME = 5000; // 5 seconds
const dismissTimeouts = new Map<string, any>();

// When a new notification arrives, add it to the rack
try {
  notifd?.connect?.("notified", (_: any, n: any) => {
    console.log("[Notifications] New notification received:", n?.summary, n?.body);
    // Add to rack
    setRackNotifications(prev => {
      const newRack = [...prev, n];
      console.log("[Notifications] Rack now has", newRack.length, "notifications");
      return newRack;
    });
    
    // Set auto-dismiss timer
    const timeoutId = setTimeout(() => {
      dismissNotification(n);
    }, AUTO_DISMISS_TIME);
    
    if (n?.id) {
      dismissTimeouts.set(n.id, timeoutId);
    }
  });
  console.log("[Notifications] Service connected to notifd:", !!notifd);
} catch (error) {
  console.error("[Notifications] Failed to connect:", error);
}

// Legacy popup state for backward compatibility
export const [lastPopup, setLastPopup] = createState<any | null>(null);
export const [popupVisible, setPopupVisible] = createState(false);

// Helpers to interact with notifications
export function dismissNotification(n: any) {
  try { 
    // Clear auto-dismiss timeout if exists
    if (n?.id && dismissTimeouts.has(n.id)) {
      const timeoutId = dismissTimeouts.get(n.id);
      if (timeoutId) clearTimeout(timeoutId);
      dismissTimeouts.delete(n.id);
    }
    
    // Remove from rack
    setRackNotifications(prev => prev.filter(item => item.id !== n.id));
    
    // Dismiss from system
    n?.dismiss?.(); 
  } catch {}
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

