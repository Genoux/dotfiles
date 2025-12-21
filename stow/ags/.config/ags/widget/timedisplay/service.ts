import { createPoll } from "ags/time";
import GLib from "gi://GLib";

export const time = createPoll("", 1000, ["date", "+%a %d %b %H:%M"]);

export function openCalendar() {
  try {
    GLib.spawn_command_line_async('launch-or-focus "calcure" "calcure"');
  } catch (error) {
    console.error("Failed to launch calendar:", error);
  }
}
