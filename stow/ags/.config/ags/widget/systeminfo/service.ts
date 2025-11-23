import GLib from "gi://GLib";

export function openSystemInfo() {
  try {
    GLib.spawn_command_line_async('launch-or-focus "system-info" "fastfetch" "system-info"');
  } catch (error) {
    console.error("Failed to launch launch-system:", error);
  }
}

