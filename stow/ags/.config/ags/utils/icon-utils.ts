import Apps from "gi://AstalApps";

// Build icon lookup map once on startup
const iconLookup = new Map<string, string>();

try {
  const apps = new Apps.Apps();
  const allApps = apps.get_list();
  
  for (const app of allApps) {
    const name = app.name?.toLowerCase();
    const entry = app.entry?.toLowerCase();
    const iconName = app.iconName;
    
    if (iconName) {
      if (name) iconLookup.set(name, iconName);
      if (entry) iconLookup.set(entry, iconName);
      
      // Also map without common suffixes
      if (entry?.endsWith(".desktop")) {
        iconLookup.set(entry.replace(".desktop", ""), iconName);
      }
    }
  }
  
  print(`[icon-utils] Loaded ${iconLookup.size} app icon mappings`);
} catch (e) {
  console.warn("Failed to load AstalApps:", e);
}

export function getAppIcon(className: string): string {
  if (!className) return "application-x-executable";

  const lowerClass = className.toLowerCase();

  // Look up in pre-built map (O(1) lookup, no CPU overhead)
  return iconLookup.get(lowerClass) || lowerClass || "application-x-executable";
}
