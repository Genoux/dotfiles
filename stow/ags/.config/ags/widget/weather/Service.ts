import { createPoll } from "ags/time";
import GLib from "gi://GLib";

// Get city/lat/lon once at startup (blocking is OK for a one-time call)
function getLocation(): { lat: number; lon: number; city: string } {
  try {
    const out = GLib.spawn_command_line_sync(
      "curl -s --max-time 10 --connect-timeout 5 http://ip-api.com/json/"
    )[1];
    if (!out) throw new Error("No data");
    const data = JSON.parse(new TextDecoder().decode(out!));
    return { lat: data.lat, lon: data.lon, city: data.city };
  } catch {
    // Fallback: Montreal
    return { lat: 45.5017, lon: -73.5673, city: "Montreal" };
  }
}
const { lat, lon, city } = getLocation();

function getWeatherIconFromWMOCode(code: number) {
  if (code === 0) return "☀️";
  if (code <= 3) return "⛅";
  if (code <= 48) return "🌫️";
  if (code <= 57) return "🌦️";
  if (code <= 67) return "🌧️";
  if (code <= 77) return "❄️";
  if (code <= 82) return "🌧️";
  if (code <= 86) return "❄️";
  if (code <= 99) return "⛈️";
  return "🌡️";
}

// Poll every 10 minutes (600,000 ms)
export const weather = createPoll(
  { temperature: 0, feelsLike: 0, icon: "🌡️", location: city },
  600000,
  () => {
    try {
      const url = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,apparent_temperature,weather_code&timezone=auto`;
      const out = GLib.spawn_command_line_sync(`curl -s --max-time 15 --connect-timeout 8 '${url}'`)[1];
      if (!out) throw new Error("No data");
      const data = JSON.parse(new TextDecoder().decode(out!));
      const c = data.current;
      return {
        temperature: Math.round(c.temperature_2m),
        feelsLike: Math.round(c.apparent_temperature),
        icon: getWeatherIconFromWMOCode(c.weather_code),
        location: city,
      };
    } catch {
      return { temperature: 0, feelsLike: 0, icon: "🌡️", location: city };
    }
  }
);

export function openWeatherApp() {
  
  GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-wthrr`);
}
