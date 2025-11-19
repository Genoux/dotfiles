import GLib from "gi://GLib";

export function openSystemInfo() {
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-system-info`);
  } catch (error) {
    console.error("Failed to launch launch-system:", error);
  }
}

