import GLib from "gi://GLib";
import { createState } from "ags";
import Hyprland from "gi://AstalHyprland";



export enum ConnectionType {
  Wifi = "wifi",
  Ethernet = "ethernet",
  None = "none"
}

export const [connectionType, setConnectionType] = createState<ConnectionType>(ConnectionType.None);
export const [connectionIcon, setConnectionIcon] = createState<string>("network-offline-symbolic");

function checkConnection() {
  try {
    // Check if we have an active network connection
    const [success, stdout] = GLib.spawn_command_line_sync("ip route get 8.8.8.8");
    
    if (!success || !stdout) {
      setConnectionType(ConnectionType.None);
      setConnectionIcon("network-offline-symbolic");
      return;
    }

    const output = new TextDecoder().decode(stdout);

    // Look for the device name in the output
    const match = output.match(/dev\s+(\w+)/);

    if (match) {
      const interfaceName = match[1];

      // Check if it's a wireless interface
      if (interfaceName.startsWith("wl") || interfaceName.startsWith("wlan") || interfaceName.includes("wifi")) {
        setConnectionType(ConnectionType.Wifi);
        setConnectionIcon("network-wireless-symbolic");
      } else if (interfaceName.startsWith("eth") || interfaceName.startsWith("en") || interfaceName.startsWith("enp")) {
        setConnectionType(ConnectionType.Ethernet);
        setConnectionIcon("network-wired-symbolic");
      } else {
        // For other interfaces like tailscale, bridge, etc., default to ethernet
        setConnectionType(ConnectionType.Ethernet);
        setConnectionIcon("network-wired-symbolic");
      }
    } else {
      setConnectionType(ConnectionType.None);
      setConnectionIcon("network-offline-symbolic");
    }
  } catch (error) {
    console.error("Network check error:", error);
    setConnectionType(ConnectionType.None);
    setConnectionIcon("network-offline-symbolic");
  }
}

checkConnection();
GLib.timeout_add(GLib.PRIORITY_DEFAULT, 5000, () => {
  checkConnection();
  return true;
});

export function getConnectionIcon(): string {
  return connectionIcon.get();
}

export function openInternetManager() {
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-impala`);
  } catch (error) {
    console.error("Failed to launch launch-impala:", error);
  }
}