import { launchOrFocus } from "../../services/hyprland";

export function openSystemInfo() {
  void launchOrFocus("system-info", "fastfetch", "system-info").catch((error) => {
    console.error("Failed to launch system-info:", error);
  });
}

