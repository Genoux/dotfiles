import GLib from "gi://GLib";

export function openDotfilesMenu() {
  try {
    GLib.spawn_command_line_async('launch-dotfiles-menu');
  } catch (error) {
    console.error("Failed to launch dotfiles menu:", error);
  }
}

