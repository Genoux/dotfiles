import Tray from "gi://AstalTray";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import { createBinding } from "ags";
import { execAsync } from "ags/process";

const tray = Tray.get_default();

function filterValidItems(items: Tray.TrayItem[]): Tray.TrayItem[] {
  if (!items || items.length === 0) {
    return [];
  }

  const validItems = items.filter((item) => {
    return item && item.id && item.gicon;
  });

  const seen = new Set<string>();
  const deduplicatedItems = validItems.filter((item) => {
    const normalizedId = item.id
      .toLowerCase()
      .replace(/[_-]/g, "-")
      .replace(/^tray-/, "")
      .replace(/-tray$/, "")
      .replace(/-client$/, "");

    if (seen.has(normalizedId)) {
      return false;
    }

    seen.add(normalizedId);
    return true;
  });

  return deduplicatedItems;
}

export const trayItems = createBinding(tray, "items").as(filterValidItems);

export function registerIconTheme(item: Tray.TrayItem) {
  if (item.iconThemePath) {
    const display = Gdk.Display.get_default();
    if (display) {
      const iconTheme = Gtk.IconTheme.get_for_display(display);
      iconTheme.add_search_path(item.iconThemePath);
    }
  }
}

async function focusWindow(item: Tray.TrayItem) {
  const appName = item.id.replace(/[_-].*$/, "").toLowerCase();
  try {
    await execAsync(["hyprctl", "dispatch", "focuswindow", `class:${appName}`]);
    return true;
  } catch {
    return false;
  }
}

export async function handlePrimaryClick(item: Tray.TrayItem) {
  try {
    item.activate(0, 0);
    await focusWindow(item);
  } catch (error) {
    console.error(`Tray activation failed for ${item.id}:`, error);
  }
}

export function handleSecondaryClick(item: Tray.TrayItem, widget: Gtk.Widget) {
  try {
    if (item.menu_model) {
      item.about_to_show();
      const popover = new Gtk.PopoverMenu();
      popover.set_menu_model(item.menu_model);
      popover.set_parent(widget);
      popover.popup();
    } else {
      item.secondary_activate(0, 0);
    }
  } catch (error) {
    console.error(`Tray secondary action failed for ${item.id}:`, error);
  }
}

export function handleMiddleClick(item: Tray.TrayItem) {
  try {
    item.secondary_activate(0, 0);
  } catch (error) {
    console.error(`Tray middle click failed for ${item.id}:`, error);
  }
}

