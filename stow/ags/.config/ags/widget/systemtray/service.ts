import Tray from "gi://AstalTray";
import { createBinding } from "ags";

const tray = Tray.get_default();

// Enhanced filtering and deduplication for tray items
function filterValidItems(items: Tray.TrayItem[]): Tray.TrayItem[] {
  if (!items || items.length === 0) {
    console.log("No tray items received");
    return [];
  }

  console.log(`Processing ${items.length} tray items`);

  const validItems = items.filter((item) => {
    try {
      // Check if item exists and has required properties
      if (!item || !item.id) {
        console.log("Filtering out item: missing id");
        return false;
      }

      // Check if item has a valid icon
      if (!item.gicon) {
        console.log(`Filtering out item ${item.id}: missing icon`);
        return false;
      }

      // Log valid items for debugging
      console.log(`Valid tray item: ${item.id}, title: ${item.title?.[0] || 'none'}`);
      return true;
    } catch (e) {
      console.log("Error filtering tray item:", e instanceof Error ? e.message : String(e));
      return false;
    }
  });

  console.log(`Found ${validItems.length} valid tray items`);

  // Enhanced deduplication with better ID normalization
  const seen = new Set<string>();
  const deduplicatedItems = validItems.filter((item) => {
    try {
      // Normalize the ID for better deduplication
      const normalizedId = item.id
        .toLowerCase()
        .replace(/[_-]/g, "-")
        .replace(/^tray-/, "")
        .replace(/-tray$/, "")
        .replace(/-client$/, "");

      if (seen.has(normalizedId)) {
        console.log(`Deduplicating tray item: ${item.id} (normalized: ${normalizedId})`);
        return false;
      }

      seen.add(normalizedId);
      return true;
    } catch (e) {
      console.log("Error during deduplication:", e instanceof Error ? e.message : String(e));
      return false;
    }
  });

  console.log(`Final tray items count: ${deduplicatedItems.length}`);
  return deduplicatedItems;
}

// Create the binding with error handling
export const trayItems = createBinding(tray, "items")
  .as(filterValidItems)
  .as((items) => {
    // Additional stability check
    if (!Array.isArray(items)) {
      console.warn("Tray items is not an array, returning empty array");
      return [];
    }
    return items;
  });

