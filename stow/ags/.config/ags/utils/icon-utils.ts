import Apps from "gi://AstalApps";
import Gtk from "gi://Gtk";
import Gdk from "gi://Gdk";

// Build icon lookup map once on startup
const iconLookup = new Map<string, string>();

// Initialize GTK icon theme
let iconTheme: Gtk.IconTheme | null = null;
try {
  const display = Gdk.Display.get_default();
  if (display) {
    iconTheme = Gtk.IconTheme.get_for_display(display);
  }
} catch (e) {
  console.warn("Failed to get GTK icon theme:", e);
}

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

function lookupIconInTheme(iconName: string): boolean {
  if (!iconTheme) return false;
  
  try {
    // Use has_icon method which is simpler and more reliable
    return iconTheme.has_icon(iconName);
  } catch {
    return false;
  }
}

function generateIconVariations(className: string): string[] {
  const variations: string[] = [];
  const lowerClass = className.toLowerCase();
  
  // Add the class name as-is
  variations.push(lowerClass);
  
  // Common transformations
  variations.push(lowerClass.replace(/-/g, ""));
  variations.push(lowerClass.replace(/_/g, "-"));
  variations.push(lowerClass.replace(/_/g, ""));
  
  // Add common prefixes/suffixes
  variations.push(`${lowerClass}-desktop`);
  variations.push(`${lowerClass}-app`);
  variations.push(`${lowerClass}-bin`);
  
  // Remove common suffixes
  const withoutSuffixes = lowerClass.replace(/(-desktop|-app|-bin|-gtk|-qt)$/, "");
  if (withoutSuffixes !== lowerClass) {
    variations.push(withoutSuffixes);
  }
  
  return [...new Set(variations)]; // Remove duplicates
}

export function getAppIcon(className: string): string {
  if (!className) return "application-x-executable";

  const lowerClass = className.toLowerCase();

  // First try the pre-built map from AstalApps
  if (iconLookup.has(lowerClass)) {
    const iconName = iconLookup.get(lowerClass)!;
    if (lookupIconInTheme(iconName)) {
      return iconName;
    }
  }

  // Generate variations and check each one
  const variations = generateIconVariations(lowerClass);
  
  for (const variation of variations) {
    // Check if this variation exists in our lookup
    if (iconLookup.has(variation)) {
      const iconName = iconLookup.get(variation)!;
      if (lookupIconInTheme(iconName)) {
        return iconName;
      }
    }
    
    // Check if this variation exists directly in the icon theme
    if (lookupIconInTheme(variation)) {
      return variation;
    }
  }

  // Try partial matches in the lookup map
  for (const [key, icon] of iconLookup) {
    if (lowerClass.includes(key) || key.includes(lowerClass)) {
      if (lookupIconInTheme(icon)) {
        return icon;
      }
    }
  }

  // Final fallback
  return "application-x-executable";
}
