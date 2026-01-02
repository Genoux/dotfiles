import GLib from "gi://GLib";
import Gio from "gi://Gio";
import { createState } from "ags";
import { timeout } from "ags/time";

export interface Position {
  ip: string;
  city: string;
  region: string;
  country: string;
  lat: number;
  lon: number;
}

const CACHE_FILE = `${GLib.get_user_cache_dir()}/ags/position.json`;
const CACHE_MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours

function ensureCacheDir(): void {
  const cacheDir = `${GLib.get_user_cache_dir()}/ags`;
  GLib.mkdir_with_parents(cacheDir, 0o755);
}

function readCache(): Position | null {
  try {
    const [ok, contents] = GLib.file_get_contents(CACHE_FILE);
    if (!ok || !contents) return null;

    const data = JSON.parse(new TextDecoder().decode(contents));

    // Check cache age
    if (data.timestamp && Date.now() - data.timestamp < CACHE_MAX_AGE_MS) {
      return data.position as Position;
    }
  } catch {}
  return null;
}

function writeCache(position: Position): void {
  try {
    ensureCacheDir();
    const data = JSON.stringify({ position, timestamp: Date.now() });
    GLib.file_set_contents(CACHE_FILE, data);
  } catch (e) {
    console.error("[Position] Failed to write cache:", e);
  }
}

function httpGet(url: string, maxTime = 10, connectTimeout = 5): string | null {
  try {
    const [success, stdout] = GLib.spawn_command_line_sync(
      `curl -s --max-time ${maxTime} --connect-timeout ${connectTimeout} '${url}'`
    );
    if (!success || !stdout) return null;
    return new TextDecoder().decode(stdout);
  } catch {
    return null;
  }
}

function fetchPosition(): Position | null {
  // Try ip-api.com first (no API key needed, 45 req/min limit)
  try {
    const response = httpGet("http://ip-api.com/json/?fields=status,message,country,regionName,city,lat,lon,query");
    if (response) {
      const data = JSON.parse(response);
      if (data.status === "success") {
        return {
          ip: data.query,
          city: data.city,
          region: data.regionName,
          country: data.country,
          lat: data.lat,
          lon: data.lon,
        };
      }
    }
  } catch {}

  // Fallback to ipinfo.io
  try {
    const response = httpGet("https://ipinfo.io/json");
    if (response) {
      const data = JSON.parse(response);
      if (data.city && data.loc) {
        const [lat, lon] = data.loc.split(",").map(Number);
        return {
          ip: data.ip,
          city: data.city,
          region: data.region,
          country: data.country,
          lat,
          lon,
        };
      }
    }
  } catch {}

  return null;
}

// Reactive position state
const [refreshTick, setRefreshTick] = createState(0);

function loadPosition(): Position | null {
  // Try cache first
  const cached = readCache();
  if (cached) {
    return cached;
  }

  // Fetch fresh position
  const fresh = fetchPosition();
  if (fresh) {
    console.log("[Position] Fetched position:", fresh.city);
    writeCache(fresh);
    return fresh;
  }

  console.warn("[Position] Failed to get position, no cache available");
  return null;
}

export const position = refreshTick(() => loadPosition());

// Trigger initial load
const triggerRefresh = () => setRefreshTick((v) => v + 1);
triggerRefresh();

// Refresh every 6 hours
timeout(6 * 60 * 60 * 1000, () => {
  triggerRefresh();
  return true;
});

// Refresh on network reconnection
(() => {
  try {
    const net = Gio.NetworkMonitor.get_default();
    let wasConnected = net.get_network_available?.() ?? true;
    let lastTrigger = 0;

    net.connect("network-changed", (_m: unknown, available: boolean) => {
      if (!wasConnected && available) {
        const now = Date.now();
        if (now - lastTrigger > 5000) {
          lastTrigger = now;
          // Only refresh if we don't have cached position
          if (!readCache()) {
            triggerRefresh();
          }
        }
      }
      wasConnected = available;
    });
  } catch (e) {
    console.error("[Position] Failed to setup network monitoring:", e);
  }
})();

export function forcePositionRefresh(): void {
  triggerRefresh();
}

export function getPositionSync(): Position | null {
  return loadPosition();
}
