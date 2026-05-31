import Tray from "gi://AstalTray";
import Playerctl from "gi://Playerctl";
import Gtk from "gi://Gtk?version=4.0";
import Gdk from "gi://Gdk?version=4.0";
import { createBinding } from "ags";
import { execAsync } from "ags/process";
import { markPlayerIdAsInteracted } from "../mediaplayer/service";
import { focusWindow } from "../../services/hyprland";

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

function playerNameStableId(name: Playerctl.PlayerName): string {
  return `${name.source}:${name.name}:${name.instance}`;
}

function trayItemMatchesPlayerName(item: Tray.TrayItem, name: Playerctl.PlayerName): boolean {
  const id = (item.id || "").toLowerCase();
  const itemTitle = (item.title || "").toLowerCase();
  const playerName = (name.name || "").toLowerCase();
  const instance = (name.instance || "").toLowerCase();

  if (playerName && (id.includes(playerName) || itemTitle.includes(playerName))) {
    return true;
  }

  if (instance && (id.includes(instance) || itemTitle.includes(instance))) {
    return true;
  }

  const idSegments = id.split(/[._-]+/).filter((s) => s.length > 2);
  if (idSegments.some((seg) => playerName.includes(seg) || instance.includes(seg))) {
    return true;
  }

  return false;
}

function markMediaPlayerForTrayItem(item: Tray.TrayItem) {
  for (const name of Playerctl.list_players()) {
    if (trayItemMatchesPlayerName(item, name)) {
      markPlayerIdAsInteracted(playerNameStableId(name));
      return;
    }
  }
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
  const tokens = [...new Set([id, ...id.split(/[._-]+/), title.slice(0, 24)])].filter(
    (t) => t && t.length > 2
  );

  const match = clients.find((c) => {
    const cls = (c.class || "").toLowerCase();
    const initialClass = (c.initialClass || "").toLowerCase();
    const ttl = (c.title || "").toLowerCase();
    return tokens.some(
      (tok) =>
        cls.includes(tok) || initialClass.includes(tok) || tok.includes(cls) || ttl.includes(tok)
    );
  });

  if (match?.address) {
    await focusWindow(`address:${match.address}`);
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
    markMediaPlayerForTrayItem(item);
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
