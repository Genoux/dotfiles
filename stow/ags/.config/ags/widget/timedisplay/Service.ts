import { createPoll } from "ags/time";
import GLib from "gi://GLib?version=2.0";

export const time = createPoll("", 1000, ["date", "+%a %d %b %H:%M"]);

export function openCalendar() {
  try {
    GLib.spawn_command_line_async(`gnome-calendar`);
  } catch (error) {
    console.error("Failed to launch calcure:", error);
  }
}
  