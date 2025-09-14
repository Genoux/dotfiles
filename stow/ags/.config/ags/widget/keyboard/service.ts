import Hyprland from "gi://AstalHyprland";
import { createState } from "ags";
import GLib from "gi://GLib";

// Get the actual current layout on startup
function getCurrentLayout(): string {
  try {
    const [success, stdout] = GLib.spawn_command_line_sync("hyprctl devices -j");
    if (success && stdout) {
      const data = JSON.parse(new TextDecoder().decode(stdout));
      const keyboards = data.keyboards || [];
      
      for (const keyboard of keyboards) {
        if (keyboard.active_keymap) {
          const layout = keyboard.active_keymap.toLowerCase();
          if (layout.includes('french') || layout.includes('canada')) {
            return "FR";
          }
        }
      }
    }
  } catch (error) {
    console.error("Failed to get current layout:", error);
  }
  return "EN";
}

// Start with the actual current layout
export const [keyboardLayout, setKeyboardLayout] = createState<string>(getCurrentLayout());

// Simple switch function
export function switchKeyboardLayout(): void {
  try {
    // Use your exact binding command
    GLib.spawn_command_line_async("hyprctl switchxkblayout next");
    
    // Toggle the display manually since we know it's just EN/FR
    setKeyboardLayout(current => current === "EN" ? "FR" : "EN");
  } catch (error) {
    console.error("Failed to switch keyboard layout:", error);
  }
}

// Connect to Hyprland events to sync state
try {
  const hypr = Hyprland.get_default();
  hypr.connect("keyboard-layout", (self: any, keyboard: string, layout: string) => {
    if (layout.toLowerCase().includes('french')) {
      setKeyboardLayout("FR");
    } else {
      setKeyboardLayout("EN");
    }
  });
} catch {
  // No Hyprland, that's fine
}