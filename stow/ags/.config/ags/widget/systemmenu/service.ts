import GLib from "gi://GLib";

export function openSystemMenu() {
  try {
    GLib.spawn_command_line_async(
      "walker --provider menus:system --nohints --nosearch"
    );
  } catch (error) {
    console.error("Failed to open system menu:", error);
  }
}
