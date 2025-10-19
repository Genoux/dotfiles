import Tray from "gi://AstalTray";
import { createBinding } from "ags";

const tray = Tray.get_default();

// Filter and deduplicate tray items
function filterValidItems(items: Tray.TrayItem[]): Tray.TrayItem[] {
  const validItems = items.filter((item) => {
    try {
      return item && item.id;
    } catch {
      return false;
    }
  });

  // Deduplicate by id
  const seen = new Set<string>();
  return validItems.filter((item) => {
    if (seen.has(item.id)) return false;
    seen.add(item.id);
    return true;
  });
}

export const trayItems = createBinding(tray, "items").as(filterValidItems);

