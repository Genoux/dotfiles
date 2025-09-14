import { createPoll } from "ags/time";
import GLib from "gi://GLib";

// Helper: Get CPU temp from sensors (supports k10temp or coretemp)
function parseCpuTemp(text: string): number {
  // Try AMD (k10temp)
  let match = text.match(/Tctl:\s*\+?(\d+\.\d+)°C/);
  if (match) return Math.round(parseFloat(match[1]));
  // Try Intel (coretemp)
  match = text.match(/Core 0:\s*\+?(\d+\.\d+)°C/);
  if (match) return Math.round(parseFloat(match[1]));
  // fallback
  return 0;
}

// Helper: Get GPU temp (Nvidia, AMD, Intel)
function getGpuTemp(): number {
  try {
    const out = GLib.spawn_command_line_sync(
      "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits"
    )[1];
    if (!out) return 0;
    const temp = parseInt(new TextDecoder().decode(out!).trim());
    return isNaN(temp) ? 0 : temp;
  } catch (e) {
    return 0;
  }
}

// Helper: get status based on max temp
function getTempStatus(cpu: number, gpu: number): "normal" | "warm" | "hot" {
  const max = Math.max(cpu, gpu);
  if (max >= 85) return "hot";
  if (max >= 70) return "warm";
  return "normal";
}

// Poll both temps every 10 seconds
export const systemTemps = createPoll(
  { cpu: 0, gpu: 0, avg: 0, status: "normal" },
  10000,
  () => {
    // CPU temp
    let cpu = 0;
    try {
      const out = GLib.spawn_command_line_sync("sensors")[1];
      if (out) cpu = parseCpuTemp(new TextDecoder().decode(out));
    } catch (e) { }

    // GPU temp
    const gpu = getGpuTemp();

    // Average and status
    const avg = Math.round((cpu + gpu) / 2);
    const status = getTempStatus(cpu, gpu);

    return { cpu, gpu, avg, status };
  }
);

export function openSystemMonitor() {
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-btop`);
  } catch (error) {
    console.error("Failed to launch btop:", error);
  }
}
