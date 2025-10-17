import GLib from "gi://GLib";
import { createPoll } from "ags/time";

function checkConnection(): string {
  try {
    // Check if we have an active network connection
    const [success, stdout] = GLib.spawn_command_line_sync("ip route get 8.8.8.8");

    if (!success || !stdout) {
      return "network-offline-symbolic";
    }

    const output = new TextDecoder().decode(stdout);

    // Look for the device name in the output
    const match = output.match(/dev\s+(\w+)/);

    if (match) {
      const interfaceName = match[1];

      // Check if it's a wireless interface
      if (
        interfaceName.startsWith("wl") ||
        interfaceName.startsWith("wlan") ||
        interfaceName.includes("wifi")
      ) {
        return "network-wireless-symbolic";
      } else if (
        interfaceName.startsWith("eth") ||
        interfaceName.startsWith("en") ||
        interfaceName.startsWith("enp")
      ) {
        return "network-wired-symbolic";
      } else {
        // For other interfaces like tailscale, bridge, etc., default to ethernet
        return "network-wired-symbolic";
      }
    } else {
      return "network-offline-symbolic";
    }
  } catch (error) {
    console.error("Network check error:", error);
    return "network-offline-symbolic";
  }
}

// Poll connection every 5 seconds
export const connectionIcon = createPoll("network-offline-symbolic", 5000, checkConnection);

export function openInternetManager() {
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-impala`);
  } catch (error) {
    console.error("Failed to launch launch-impala:", error);
  }
}
