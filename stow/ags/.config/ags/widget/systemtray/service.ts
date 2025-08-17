import Tray from "gi://AstalTray";
import { createBinding } from "ags";

const tray = Tray.get_default();

// Function to filter valid tray items
function filterValidItems(items: Tray.TrayItem[]): Tray.TrayItem[] {
  return items.filter(item => {
    try {
      // Check if item is valid and has necessary properties
      return item && 
             item.gicon && 
             item.id && 
             !item.get_property?.("invalid") && // Check if item is marked as invalid
             item.get_property?.("status") !== "Passive"; // Filter out passive items
    } catch (error) {
      console.warn("Invalid tray item detected, filtering out:", error);
      return false;
    }
  });
}

// Create binding that filters items
export const trayItems = createBinding(tray, "items", (items: Tray.TrayItem[]) => {
  return filterValidItems(items);
});
