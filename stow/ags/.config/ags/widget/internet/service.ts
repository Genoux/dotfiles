import GLib from "gi://GLib";
import Gio from "gi://Gio";
import { createState } from "ags";

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

// Reactive connectivity state using NetworkMonitor
const [connected, setConnected] = createState<boolean>(false);

try {
  const net = Gio.NetworkMonitor.get_default();
  // initial state
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const initial = (net as any).get_network_available ? net.get_network_available() : true;
  setConnected(() => !!initial);

  let last = Date.now();
  net.connect("network-changed", (_m, available: boolean) => {
    const now = Date.now();
    if (now - last < 500) return; // debounce bursts
    last = now;
    setConnected(() => !!available);
  });
} catch (error) {
  // Fallback: best-effort probe immediately
  setConnected(() => checkConnection() !== "network-offline-symbolic");
}

// Export a simple boolean state to reuse elsewhere
export { connected };

// Derive an icon reactively from connectivity; keep it simple (no iface detection here)
export const connectionIcon = connected((isOn) =>
  isOn ? "network-wired-symbolic" : "network-offline-symbolic"
);

export function openInternetManager() {
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-impala`);
  } catch (error) {
    console.error("Failed to launch launch-impala:", error);
  }
}
