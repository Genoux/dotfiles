import Tray from "gi://AstalTray";
import Mpris from "gi://AstalMpris";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import { createBinding } from "ags";
import { execAsync } from "ags/process";
import { markPlayerAsInteracted } from "../mediaplayer/service";

const tray = Tray.get_default();

function filterValidItems(items: Tray.TrayItem[]): Tray.TrayItem[] {
  if (!items || items.length === 0) {
    return [];
  }

  // Filter out invalid items, but don't deduplicate - let AstalTray handle uniqueness
  const validItems = items.filter((item) => {
    return item && item.id && item.gicon;
  });

  return validItems;
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

function trayItemMatchesMprisPlayer(item: Tray.TrayItem, player: Mpris.Player): boolean {
  const id = (item.id || "").toLowerCase();
  const itemTitle = (item.title || "").toLowerCase();
  const bus = (player.bus_name || "").toLowerCase();
  const busShort = bus.replace("org.mpris.mediaplayer2.", "");
  const entry = (player.entry || "").replace(/\.desktop$/i, "").toLowerCase();

  if (entry && (id.includes(entry) || itemTitle.includes(entry))) {
    return true;
  }

  const idSegments = id.split(/[._-]+/).filter((s) => s.length > 2);
  if (idSegments.some((seg) => bus.includes(seg))) {
    return true;
  }

  if (busShort.length > 0 && (id.includes(busShort) || busShort.split(".").some((p) => p.length > 2 && id.includes(p)))) {
    return true;
  }

  return false;
}

function raiseMprisForTrayItem(item: Tray.TrayItem): boolean {
  const mpris = Mpris.get_default();
  for (const player of mpris.players) {
    if (!player.can_raise || !trayItemMatchesMprisPlayer(item, player)) {
      continue;
    }
    markPlayerAsInteracted(player);
    player.raise();
    return true;
  }
  return false;
}

async function focusHyprWindowForTrayItem(item: Tray.TrayItem) {
  let clients: { address?: string; class?: string; initialClass?: string; title?: string }[];
  try {
    const json = await execAsync(["hyprctl", "clients", "-j"]);
    clients = JSON.parse(json);
  } catch {
    return;
  }

  const id = (item.id || "").toLowerCase();
  const title = (item.title || "").toLowerCase();
  const tokens = [...new Set([id, ...id.split(/[._-]+/), title.slice(0, 24)])].filter((t) => t && t.length > 2);

  const match = clients.find((c) => {
    const cls = (c.class || "").toLowerCase();
    const initialClass = (c.initialClass || "").toLowerCase();
    const ttl = (c.title || "").toLowerCase();
    return tokens.some(
      (tok) =>
        cls.includes(tok) ||
        initialClass.includes(tok) ||
        tok.includes(cls) ||
        ttl.includes(tok),
    );
  });

  if (match?.address) {
    await execAsync(["hyprctl", "dispatch", "focuswindow", `address:${match.address}`]);
  }
}

export function openTrayMenu(item: Tray.TrayItem, widget: any) {
  if (!item.menu_model || !widget) {
    return;
  }
  try {
    item.about_to_show();
    const popover = new Gtk.PopoverMenu();
    popover.set_menu_model(item.menu_model);
    if (typeof widget.get_parent === "function") {
      popover.set_parent(widget);
      popover.popup();
    }
  } catch (error) {
    console.error(`Tray menu failed for ${item.id}:`, error);
  }
}

export async function handlePrimaryClick(item: Tray.TrayItem) {
  try {
    item.activate(0, 0);

    if (raiseMprisForTrayItem(item)) {
      return;
    }

    await focusHyprWindowForTrayItem(item);
  } catch (error) {
    console.error(`Tray activation failed for ${item.id}:`, error);
  }
}

export function handleSecondaryClick(item: Tray.TrayItem, widget: any) {
  try {
    if (item.menu_model) {
      openTrayMenu(item, widget);
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

