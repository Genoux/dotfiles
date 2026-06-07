import GLib from "gi://GLib";
import Gio from "gi://Gio";
import { createState } from "ags";
import { launchOrFocus } from "../../services/hyprland";
import { httpGet } from "../../services/network";
import { getPositionSync } from "../../services/position";

interface WeatherData {
  temperature: number;
  feelsLike: number;
  icon: string;
  location: string;
}

function getWeatherIcon(code: number): string {
  // OpenWeatherMap weather codes
  if (code === 800) return "☀️"; // clear sky
  if (code === 801) return "🌤️"; // few clouds
  if (code === 802) return "⛅"; // scattered clouds
  if (code === 803 || code === 804) return "☁️"; // broken/overcast clouds
  if (code >= 200 && code < 300) return "⛈️"; // thunderstorm
  if (code >= 300 && code < 400) return "🌦️"; // drizzle
  if (code >= 500 && code < 600) return "🌧️"; // rain
  // Snow codes: 600-622 (light snow, snow, heavy snow, sleet, etc.)
  if (code >= 600 && code <= 622) return "❄️"; // snow
  if (code >= 700 && code < 800) return "☁️"; // atmosphere (fog, mist, etc.)
  return ""; // default
}

function getWeatherApiKey(): string | null {
  return GLib.getenv("OPENWEATHERMAP_API_KEY") || null;
}

function fetchWeather(): WeatherData | null {
  try {
    const apiKey = getWeatherApiKey();
    if (!apiKey) return null;

    const pos = getPositionSync();
    let url: string;

    if (pos && pos.lat && pos.lon) {
      // Use coordinates for more accurate weather (from position service)
      url = `https://api.openweathermap.org/data/2.5/weather?lat=${pos.lat}&lon=${pos.lon}&appid=${apiKey}&units=metric`;
    } else {
      // Fallback to hardcoded city
      const fallbackCity = GLib.getenv("WEATHER_CITY") || "Montreal";
      url = `https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(fallbackCity)}&appid=${apiKey}&units=metric`;
    }

    const response = httpGet(url);
    if (!response) throw new Error("No data");

    const data = JSON.parse(response);
    if (!data || !data.main || !data.weather || !data.weather[0]) return null;

    return {
      temperature: Math.round(data.main.temp),
      feelsLike: Math.round(data.main.feels_like),
      icon: getWeatherIcon(data.weather[0].id),
      location: data.name,
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
  // Try wego (AUR package) first, fallback to checking PATH
  const wegoPath = GLib.find_program_in_path("wego");

  if (!wegoPath) {
    console.error(`[Weather] wego not found. Install with: yay -S wego`);
    return;
  }

  const apiKey = getWeatherApiKey();
  if (!apiKey) {
    console.error("[Weather] OPENWEATHERMAP_API_KEY is not set");
    return;
  }

  // Get location from position service (use coordinates for wego, city names with special chars fail)
  const pos = getPositionSync();
  let location: string;

  if (pos && pos.lat && pos.lon) {
    // Use lat,lon format which wego accepts
    location = `${pos.lat},${pos.lon}`;
  } else {
    // Fallback to environment or default
    location = GLib.getenv("WEATHER_CITY") || "Montreal";
  }

  void launchOrFocus(
    "weather",
    wegoPath,
    "weather",
    "-owm-api-key",
    apiKey,
    "-l",
    location,
  ).catch((error) => {
    console.error("Failed to launch weather:", error);
  });
}
