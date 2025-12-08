import { createState } from "ags";
import { hypr } from "../../services/hyprland";
import GLib from "gi://GLib";

function getKeyboardDevices() {
  const [success, stdout] = GLib.spawn_command_line_sync("hyprctl devices -j");
  if (!success || !stdout) throw new Error("Failed to query devices");
  
  const data = JSON.parse(new TextDecoder().decode(stdout));
  return data.keyboards || [];
}

function getMainKeyboard(): string {
  const keyboards = getKeyboardDevices();
  const mainKeyboard = keyboards.find((kb: any) => kb.main);
  
  if (!mainKeyboard) {
    throw new Error("No main keyboard found");
  }
  
  return mainKeyboard.name;
}

function getCurrentLayout(): string {
  const keyboards = getKeyboardDevices();
  const mainKeyboard = keyboards.find((kb: any) => kb.main);
  
  if (mainKeyboard?.active_keymap) {
    const layout = mainKeyboard.active_keymap.toLowerCase();
    return layout.includes("french") || layout.includes("canada") ? "FR" : "EN";
  }
  
  return "EN";
}

export const [keyboardLayout, setKeyboardLayout] = createState(getCurrentLayout());

export function switchKeyboardLayout() {
  const keyboard = getMainKeyboard();
  GLib.spawn_command_line_async(`hyprctl switchxkblayout ${keyboard} next`);
  setKeyboardLayout((current) => (current === "EN" ? "FR" : "EN"));
}

// Sync with Hyprland events
if (hypr) {
  hypr.connect("keyboard-layout", (_self: any, _keyboard: string, layout: string) => {
    setKeyboardLayout(layout.toLowerCase().includes("french") ? "FR" : "EN");
  });
}
