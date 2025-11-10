import { createState } from "ags";
import { timeout } from "ags/time";
import GLib from "gi://GLib";
import Gio from "gi://Gio";
import { httpGet } from "../../services/network";

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

function getCity(): string {
  try {
    const response = httpGet("http://ip-api.com/json/", 10, 5);
    if (!response) throw new Error("No data");
    const data = JSON.parse(response);
    if (data && typeof data.city === "string" && data.city.length > 0) {
      return data.city;
    }
  } catch {}

  return "Montreal";
}

function fetchWeather(): WeatherData | null {
  try {
    const apiKey = GLib.getenv("OPENWEATHERMAP_API_KEY") || "d9219c0472bace98bededdf4f2701585";
    if (!apiKey) return null;

    const city = getCity();
    const url = `https://api.openweathermap.org/data/2.5/weather?q=${encodeURIComponent(city)}&appid=${apiKey}&units=metric`;
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
  } catch {
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
timeout(600000, () => {
  triggerRefresh();
  return true; // continue
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
  GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-weather`);
}
