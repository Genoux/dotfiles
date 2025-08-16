export function getNotificationIcon(notification: any): { type: "gicon" | "iconName" | "file"; value: any } {
  const appIcon = notification?.app_icon;

  if (appIcon && typeof appIcon === "object") {
    return { type: "gicon", value: appIcon };
  }

  if (typeof appIcon === "string" && appIcon.length > 0) {
    // If looks like a filesystem path or image file, use file source
    const isFilePath = appIcon.startsWith("/") || appIcon.startsWith("./") || appIcon.endsWith(".png") || appIcon.endsWith(".svg");
    if (isFilePath) {
      return { type: "file", value: appIcon };
    }
    return { type: "iconName", value: appIcon };
  }

  const desktopEntry = notification?.desktop_entry;
  if (typeof desktopEntry === "string" && desktopEntry.length > 0) {
    return { type: "iconName", value: desktopEntry };
  }

  const appName = notification?.app_name;
  if (typeof appName === "string" && appName.length > 0) {
    // best-effort: transform to typical icon name format
    const candidate = appName.toLowerCase().replaceAll(" ", "-");
    return { type: "iconName", value: candidate };
  }

  return { type: "iconName", value: "dialog-information" };
}

export function getNotificationAppName(notification: any): string {
  const appName = notification?.app_name;
  if (typeof appName === "string" && appName.length > 0) return appName;

  const desktopEntry = notification?.desktop_entry;
  if (typeof desktopEntry === "string" && desktopEntry.length > 0) return desktopEntry;

  return "Notification";
}

export function formatRelativeTime(epochMs?: number): string {
  if (!epochMs || Number.isNaN(epochMs)) return "";
  const diff = Math.max(0, Date.now() - epochMs);
  const seconds = Math.floor(diff / 1000);
  if (seconds < 60) return `${seconds}s`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  const days = Math.floor(hours / 24);
  return `${days}d`;
}

