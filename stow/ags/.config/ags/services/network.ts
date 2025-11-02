import GLib from "gi://GLib";
import Gio from "gi://Gio";
import { createState } from "ags";

const [connected, setConnected] = createState<boolean>(false);

try {
  const net = Gio.NetworkMonitor.get_default();
  const initial = (net as any).get_network_available ? net.get_network_available() : true;
  setConnected(() => !!initial);

  let last = Date.now();
  net.connect("network-changed", (_m, available: boolean) => {
    const now = Date.now();
    if (now - last < 500) return;
    last = now;
    setConnected(() => !!available);
  });
} catch (error) {
  console.error("NetworkMonitor initialization failed:", error);
  setConnected(() => true);
}

export { connected };

export function httpGet(url: string, maxTime = 15, connectTimeout = 8): string | null {
  try {
    const [success, stdout] = GLib.spawn_command_line_sync(
      `curl -s --max-time ${maxTime} --connect-timeout ${connectTimeout} '${url}'`
    );

    if (!success || !stdout) {
      return null;
    }

    return new TextDecoder().decode(stdout);
  } catch (error) {
    console.error(`HTTP GET failed for ${url}:`, error);
    return null;
  }
}

export function checkConnection(): string {
  try {
    const [success, stdout] = GLib.spawn_command_line_sync("ip route get 8.8.8.8");

    if (!success || !stdout) {
      return "network-offline-symbolic";
    }

    const output = new TextDecoder().decode(stdout);
    const match = output.match(/dev\s+(\w+)/);

    if (match) {
      const interfaceName = match[1];

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
        return "network-wireless-symbolic";
      } else {
        return "network-wireless-symbolic";
      }
    } else {
      return "network-offline-symbolic";
    }
  } catch (error) {
    console.error("Network check error:", error);
    return "network-offline-symbolic";
  }
}
