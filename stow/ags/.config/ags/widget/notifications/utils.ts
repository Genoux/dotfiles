// Utility functions for notification components

/**
 * Smart notification icon resolver
 * 
 * This function handles the complexity of getting the best available app icon
 * from a notification object. AGS notifications can have icons in different
 * properties and formats depending on how they were sent.
 * 
 * @param notification - The notification object from AGS/AstalNotifd
 * @returns Object with useGIcon flag and iconValue
 */
export function getNotificationIcon(notification: any): { useGIcon: boolean; iconValue: any } {
  if (!notification) {
    return { useGIcon: false, iconValue: "application-x-executable-symbolic" };
  }

  try {
    // Check if app_icon is a GIcon object (real app notifications)
    if (notification.app_icon && typeof notification.app_icon === 'object') {
      return { useGIcon: true, iconValue: notification.app_icon };
    }

    // Check if app_icon is a string (notify-send --icon parameter or some apps)
    if (notification.app_icon && typeof notification.app_icon === 'string' && notification.app_icon.trim() !== '') {
      return { useGIcon: false, iconValue: notification.app_icon };
    }

    // Try desktop_entry as icon name (some apps set this)
    if (notification.desktop_entry && notification.desktop_entry.trim() !== '') {
      return { useGIcon: false, iconValue: notification.desktop_entry };
    }

    // Try app_name as icon name (avoid generic names)
    if (notification.app_name && 
        notification.app_name !== "notify-send" && 
        notification.app_name.trim() !== '') {
      // Clean up app name for icon usage
      const iconName = notification.app_name.toLowerCase()
        .replace(/\s+/g, '-')           // spaces to dashes
        .replace(/[^a-z0-9\-_.]/g, '')  // remove invalid chars, keep dots and underscores
        .replace(/^-+|-+$/g, '');       // remove leading/trailing dashes
      
      if (iconName.length > 0) {
        return { useGIcon: false, iconValue: iconName };
      }
    }

    // Try the icon property (less common but some notifications use it)
    if (notification.icon && notification.icon.trim() !== '') {
      return { useGIcon: false, iconValue: notification.icon };
    }

  } catch (error) {
    console.error("Error resolving notification icon:", error);
  }

  // Default fallback - always works
  return { useGIcon: false, iconValue: "application-x-executable-symbolic" };
}

/**
 * Get a display-friendly app name from notification
 * Handles cases where app_name might be generic or missing
 */
export function getNotificationAppName(notification: any): string {
  if (!notification) {
    return "Unknown App";
  }

  // Use app_name if it's meaningful
  if (notification.app_name && 
      notification.app_name !== "notify-send" && 
      notification.app_name.trim() !== '') {
    return notification.app_name;
  }

  // Try desktop_entry as fallback
  if (notification.desktop_entry && notification.desktop_entry.trim() !== '') {
    // Convert desktop entry to readable name (e.g. "org.mozilla.firefox" -> "Firefox")
    const parts = notification.desktop_entry.split('.');
    const lastPart = parts[parts.length - 1];
    return lastPart.charAt(0).toUpperCase() + lastPart.slice(1);
  }

  return "Unknown App";
}
