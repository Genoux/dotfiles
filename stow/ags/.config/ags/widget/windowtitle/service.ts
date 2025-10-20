import Hyprland from "gi://AstalHyprland";
import { createBinding } from "ags";

let hypr: Hyprland.Hyprland | null = null;

try {
  hypr = Hyprland.get_default();
} catch (e) {
  console.warn("Hyprland not available:", e);
}

export const focusedClient = hypr
  ? createBinding(hypr, "focusedClient")
  : null;
