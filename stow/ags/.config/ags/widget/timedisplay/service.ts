import { createPoll } from "ags/time";
import GLib from "gi://GLib";

export const time = createPoll("", 1000, ["date", "+%a %d %b %H:%M"]);

export function openCalendar() {
  try {
    GLib.spawn_command_line_async("firefoxpwa site launch 01K93BAS8XCDB5JEXER5421G71");
  } catch (error) {
    console.error("Failed to launch calendar:", error);
  }
}
