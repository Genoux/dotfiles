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

interface NetworkSpeed {
  download: number; // bytes/sec
  upload: number;   // bytes/sec
  downloadFormatted: string;
  uploadFormatted: string;
}

// Network speed tracking (same method as btop++)
let lastRx = 0;
let lastTx = 0;
let lastTime = Date.now();

// Moving average window (btop++ uses ~10 samples)
const WINDOW_SIZE = 10;
const downloadHistory: number[] = [];
const uploadHistory: number[] = [];

function formatSpeed(bytesPerSec: number): string {
  if (bytesPerSec < 1024) return `${bytesPerSec.toFixed(0)} B/s`;
  if (bytesPerSec < 1024 * 1024) return `${(bytesPerSec / 1024).toFixed(1)} KB/s`;
  if (bytesPerSec < 1024 * 1024 * 1024) return `${(bytesPerSec / (1024 * 1024)).toFixed(1)} MB/s`;
  return `${(bytesPerSec / (1024 * 1024 * 1024)).toFixed(2)} GB/s`;
}

function addToHistory(arr: number[], value: number): void {
  arr.push(value);
  if (arr.length > WINDOW_SIZE) {
    arr.shift();
  }
}

function getAverage(arr: number[]): number {
  if (arr.length === 0) return 0;
  return arr.reduce((sum, val) => sum + val, 0) / arr.length;
}

export function getNetworkSpeed(): NetworkSpeed {
  try {
    const [success, stdout] = GLib.spawn_command_line_sync("cat /proc/net/dev");
    if (!success || !stdout) {
      return { download: 0, upload: 0, downloadFormatted: "0 B/s", uploadFormatted: "0 B/s" };
    }

    const output = new TextDecoder().decode(stdout);
    const lines = output.split("\n");
    
    let totalRx = 0;
    let totalTx = 0;
    
    // Sum up all non-loopback interfaces
    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("Inter-") || trimmed.startsWith("face")) continue;
      if (trimmed.startsWith("lo:")) continue; // Skip loopback
      
      const parts = trimmed.split(/\s+/);
      if (parts.length < 10) continue;
      
      const iface = parts[0].replace(":", "");
      if (iface === "lo") continue;
      
      const rx = parseInt(parts[1]) || 0;
      const tx = parseInt(parts[9]) || 0;
      
      totalRx += rx;
      totalTx += tx;
    }
    
    const now = Date.now();
    const timeDiff = (now - lastTime) / 1000; // seconds
    
    let download = 0;
    let upload = 0;
    
    if (lastRx > 0 && lastTx > 0 && timeDiff > 0) {
      download = Math.max(0, (totalRx - lastRx) / timeDiff);
      upload = Math.max(0, (totalTx - lastTx) / timeDiff);
      
      // Add to history for moving average (same as btop++)
      addToHistory(downloadHistory, download);
      addToHistory(uploadHistory, upload);
    }
    
    lastRx = totalRx;
    lastTx = totalTx;
    lastTime = now;
    
    // Calculate moving average
    const avgDownload = getAverage(downloadHistory);
    const avgUpload = getAverage(uploadHistory);
    
    return {
      download: avgDownload,
      upload: avgUpload,
      downloadFormatted: formatSpeed(avgDownload),
      uploadFormatted: formatSpeed(avgUpload),
    };
  } catch (error) {
    console.error("Failed to get network speed:", error);
    return { download: 0, upload: 0, downloadFormatted: "0 B/s", uploadFormatted: "0 B/s" };
  }
}

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
        return "network-idle";
      } else {
        return "network-idle";
      }
    } else {
      return "network-offline";
    }
  } catch (error) {
    console.error("Network check error:", error);
    return "network-offline-symbolic";
  }
}
