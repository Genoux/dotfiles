import GLib from "gi://GLib";
import Gio from "gi://Gio";
import { createState } from "ags";
import { httpGet } from "../../services/network";

interface WeatherData {
  temperature: number;
  feelsLike: number;
  icon: string;
  location: string;
}

function fetchWeather(): WeatherData | null {
  try {
    const city = encodeURIComponent(GLib.getenv("WEATHER_CITY") || "Montreal");
    const response = httpGet(`https://wttr.in/${city}?format=%c+%t`);
    if (!response) throw new Error("No data");

    const label = response.replace(/\+/g, "").trim();
    const temperature = Number(label.match(/-?\d+(?=°C)/)?.[0]);
    if (!Number.isFinite(temperature)) return null;

    return {
      temperature,
      feelsLike: temperature,
      icon: label.replace(/-?\d+°C/, "").trim(),
      location: GLib.getenv("WEATHER_CITY") || "Montreal",
    };
  } catch (e) {
    console.error("[Weather] Failed to fetch weather:", e);
    return null;
  }
}

// Reactive weather state with manual triggers
const [refreshTick, setRefreshTick] = createState(0);
export const weather = refreshTick(() => fetchWeather());

// Fetch immediately on load
const triggerRefresh = () => setRefreshTick((v) => v + 1);
triggerRefresh();

// Refresh every 10 minutes
GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 600, () => {
  triggerRefresh();
  return true;
});

// Watch for network reconnection
(() => {
  try {
    const net = Gio.NetworkMonitor.get_default();
    let lastTrigger = 0;
    let wasConnected = (net as any).get_network_available ? net.get_network_available() : true;

    net.connect("network-changed", (_m, available: boolean) => {
      // Only trigger on transition from disconnected to connected
      if (!wasConnected && available) {
        const now = Date.now();
        if (now - lastTrigger > 2000) {
          lastTrigger = now;
          triggerRefresh();
        }
      }

      wasConnected = available;
    });
  } catch (error) {
    console.error("[Weather] Failed to setup network monitoring:", error);
  }
})();

export function forceWeatherRefresh() {
  triggerRefresh();
}

export function openWeatherApp() {
  GLib.spawn_command_line_async("gnome-weather");
}
