import { createState } from "ags";
import { hypr } from "../../lib/hyprland";
import GLib from "gi://GLib";

function getCurrentLayout(): string {
  try {
    const [success, stdout] = GLib.spawn_command_line_sync("hyprctl devices -j");
    if (success && stdout) {
      const data = JSON.parse(new TextDecoder().decode(stdout));
      const keyboards = data.keyboards || [];

      for (const keyboard of keyboards) {
        if (keyboard.active_keymap) {
          const layout = keyboard.active_keymap.toLowerCase();
          if (layout.includes("french") || layout.includes("canada")) {
            return "FR";
          }
        }
      }
    }
  } catch (e) {
    console.error("Failed to get current layout:", e);
  }
  return "EN";
}

export const [keyboardLayout, setKeyboardLayout] = createState(getCurrentLayout());

export function switchKeyboardLayout() {
  try {
    GLib.spawn_command_line_async("hyprctl switchxkblayout next");
    setKeyboardLayout((current) => (current === "EN" ? "FR" : "EN"));
  } catch (e) {
    console.error("Failed to switch keyboard layout:", e);
  }
}

// Sync with Hyprland events
if (hypr) {
  hypr.connect("keyboard-layout", (_self: any, _keyboard: string, layout: string) => {
    setKeyboardLayout(layout.toLowerCase().includes("french") ? "FR" : "EN");
  });
}
