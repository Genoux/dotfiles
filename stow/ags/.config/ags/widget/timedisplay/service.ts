import { createPoll } from "ags/time";
import GLib from "gi://GLib";

export const time = createPoll("", 1000, ["date", "+%a %d %b %H:%M"]);

export function openCalendar() {
  try {
    GLib.spawn_command_line_async("firefoxpwa site launch 01K92VV7C938FN73H4XEZZT3WF");
  } catch (error) {
    console.error("Failed to launch calendar:", error);
  }
}
