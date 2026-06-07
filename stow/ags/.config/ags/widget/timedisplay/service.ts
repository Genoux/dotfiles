import { createPoll } from "ags/time";
import { launchOrFocus } from "../../services/hyprland";

export const time = createPoll("", 1000, ["date", "+%a %d %b %H:%M"]);

export function openCalendar() {
  void launchOrFocus("calcurse", "calcurse").catch((error) => {
    console.error("Failed to launch calendar:", error);
  });
}
