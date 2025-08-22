import Tray from "gi://AstalTray";
import { createBinding } from "ags";

const tray = Tray.get_default();

// Function to filter valid tray items
function filterValidItems(items: Tray.TrayItem[]): Tray.TrayItem[] {
  // First filter for basic validity with strict gicon validation
  const validItems = items.filter(item => {
    try {
      // More strict validation - ensure gicon is actually valid and not null/undefined
      const hasValidGicon = item && item.gicon && item.gicon.toString() !== "null";
      const hasValidId = item && item.id && item.id.length > 0;
      const isNotInvalid = !item.get_property?.("invalid");
      const isNotPassive = item.get_property?.("status") !== "Passive";
      
      return hasValidGicon && hasValidId && isNotInvalid && isNotPassive;
    } catch (error) {
      console.warn("Invalid tray item detected, filtering out:", error);
      return false;
    }
  });

  // Deduplicate items by both title and id to prevent multiple empty icons from the same app
  const seenIdentifiers = new Set<string>();
  const deduplicatedItems = validItems.filter(item => {
    try {
      const title = item.title || "untitled";
      const id = item.id || "unknown";
      const identifier = `${title}:${id}`;
      
      if (seenIdentifiers.has(identifier)) {
        return false; // Skip duplicate
      }
      seenIdentifiers.add(identifier);
      return true;
    } catch (error) {
      console.warn("Error processing tray item identifier:", error);
      return false;
    }
  });

  return deduplicatedItems;
}

// Create binding that filters items
export const trayItems = createBinding(tray, "items", (items: Tray.TrayItem[]) => {
  return filterValidItems(items);
});
