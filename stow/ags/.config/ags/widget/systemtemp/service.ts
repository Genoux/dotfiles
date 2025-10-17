import { createPoll } from "ags/time";
import GLib from "gi://GLib";

type TempStatus = "normal" | "warm" | "hot";

interface SystemTemps {
  cpu: number;
  gpu: number;
  avg: number;
  status: TempStatus;
}

function parseCpuTemp(text: string): number {
  // Try AMD (k10temp)
  let match = text.match(/Tctl:\s*\+?(\d+\.\d+)°C/);
  if (match) return Math.round(parseFloat(match[1]));

  // Try Intel (coretemp)
  match = text.match(/Core 0:\s*\+?(\d+\.\d+)°C/);
  if (match) return Math.round(parseFloat(match[1]));

  return 0;
}

function getGpuTemp(): number {
  try {
    const out = GLib.spawn_command_line_sync(
      "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits"
    )[1];
    if (!out) return 0;

    const temp = parseInt(new TextDecoder().decode(out).trim());
    return isNaN(temp) ? 0 : temp;
  } catch {
    return 0;
  }
}

function getTempStatus(cpu: number, gpu: number): TempStatus {
  const max = Math.max(cpu, gpu);
  if (max >= 85) return "hot";
  if (max >= 70) return "warm";
  return "normal";
}

// Poll every 30 seconds (reduced from 10s to minimize overhead)
export const systemTemps = createPoll<SystemTemps>(
  { cpu: 0, gpu: 0, avg: 0, status: "normal" },
  30000,
  () => {
    let cpu = 0;
    try {
      const out = GLib.spawn_command_line_sync("sensors")[1];
      if (out) cpu = parseCpuTemp(new TextDecoder().decode(out));
    } catch {}

    const gpu = getGpuTemp();
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
