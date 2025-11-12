import { createState } from "ags";
import GLib from "gi://GLib";
import Gio from "gi://Gio";
import { Gtk } from "ags/gtk4";

export type TempStatus = "normal" | "warm" | "hot";

export interface SystemTemps {
  cpu: number;
  gpu: number;
  avg: number;
  status: TempStatus;
}

const [systemTempsState, setSystemTemps] = createState<SystemTemps>({
  cpu: 0,
  gpu: 0,
  avg: 0,
  status: "normal",
});

export const icons: Record<TempStatus, string> = {
  normal: "temperature-normal-symbolic",
  warm: "temperature-warm-symbolic",
  hot: "temperature-warm-symbolic",
};

function getTempStatus(cpu: number, gpu: number): TempStatus {
  const max = Math.max(cpu, gpu);
  if (max >= 85) return "hot";
  if (max >= 70) return "warm";
  return "normal";
}

export function getTempIcon(status: TempStatus): string {
  return icons[status] || icons.normal;
}

export function formatTempLabel(temps: SystemTemps): string {
  return `${temps.avg}°C`;
}

export function formatTempDetails(temps: SystemTemps): {
  cpu: string;
  gpu: string;
  avg: string;
} {
  return {
    cpu: `CPU: ${temps.cpu}°C`,
    gpu: `GPU: ${temps.gpu}°C`,
    avg: `Avg: ${temps.avg}°C`,
  };
}

function readCpuTempFromHwmon(): number {
  try {
    // Use hwmon interface (same as btop++)
    // Find CPU sensor (k10temp for AMD, coretemp for Intel, etc.)
    for (let i = 0; i < 20; i++) {
      const namePath = `/sys/class/hwmon/hwmon${i}/name`;
      const nameFile = Gio.File.new_for_path(namePath);
      
      if (!nameFile.query_exists(null)) continue;
      
      const [, nameData] = nameFile.load_contents(null);
      const name = new TextDecoder().decode(nameData).trim().toLowerCase();
      
      // Look for CPU temperature sensors
      if (name.includes("k10temp") || name.includes("coretemp") || name.includes("cpu")) {
        // Try temp1_input (usually Tctl or Package id 0 for CPU)
        for (let j = 1; j <= 3; j++) {
          const tempPath = `/sys/class/hwmon/hwmon${i}/temp${j}_input`;
          const labelPath = `/sys/class/hwmon/hwmon${i}/temp${j}_label`;
          
          const tempFile = Gio.File.new_for_path(tempPath);
          if (!tempFile.query_exists(null)) continue;
          
          // Check label to prefer Tctl (AMD) or Package (Intel)
          try {
            const labelFile = Gio.File.new_for_path(labelPath);
            if (labelFile.query_exists(null)) {
              const [, labelData] = labelFile.load_contents(null);
              const label = new TextDecoder().decode(labelData).trim().toLowerCase();
              
              // Prefer Tctl for AMD or Package for Intel
              if (label.includes("tctl") || label.includes("package") || j === 1) {
                const [, tempData] = tempFile.load_contents(null);
                const tempStr = new TextDecoder().decode(tempData).trim();
                const temp = parseInt(tempStr);
                
                if (!isNaN(temp) && temp > 0) {
                  // hwmon temps are in millidegrees, convert to Celsius
                  return Math.round(temp / 1000);
                }
              }
            } else {
              // No label file, just use temp1_input
              const [, tempData] = tempFile.load_contents(null);
              const tempStr = new TextDecoder().decode(tempData).trim();
              const temp = parseInt(tempStr);
              
              if (!isNaN(temp) && temp > 0) {
                return Math.round(temp / 1000);
              }
            }
          } catch {}
        }
      }
    }
  } catch {}
  
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

function updateTemps() {
  const cpu = readCpuTempFromHwmon();
  const gpu = getGpuTemp();
  const avg = Math.round((cpu + gpu) / 2);
  const status = getTempStatus(cpu, gpu);
  
  setSystemTemps({ cpu, gpu, avg, status });
}

// Initial read
updateTemps();

// Monitor CPU hwmon files for changes (event-driven, same method as btop++)
try {
  for (let i = 0; i < 20; i++) {
    const namePath = `/sys/class/hwmon/hwmon${i}/name`;
    const nameFile = Gio.File.new_for_path(namePath);
    
    if (!nameFile.query_exists(null)) continue;
    
    const [, nameData] = nameFile.load_contents(null);
    const name = new TextDecoder().decode(nameData).trim().toLowerCase();
    
    if (name.includes("k10temp") || name.includes("coretemp") || name.includes("cpu")) {
      // Monitor temp1_input (primary CPU temp)
      const tempPath = `/sys/class/hwmon/hwmon${i}/temp1_input`;
      const tempFile = Gio.File.new_for_path(tempPath);
      
      if (tempFile.query_exists(null)) {
        const monitor = tempFile.monitor_file(Gio.FileMonitorFlags.NONE, null);
        monitor.connect("changed", () => {
          updateTemps();
        });
        break; // Found CPU sensor, stop searching
      }
    }
  }
} catch (error) {
  console.error("Failed to setup hwmon file monitoring:", error);
}

// Fallback: Poll GPU less frequently (every 10s) since it changes slower
// and we don't have a reliable file-based source for it
const gpuPollInterval = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 10, () => {
  updateTemps();
  return true; // Continue polling
});

export const systemTemps = systemTempsState;

export function openSystemMonitor() {
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-btop`);
  } catch (error) {
    console.error("Failed to launch btop:", error);
  }
}

export function showTemperatureDetails(widget: any) {
  try {
    if (!widget || typeof widget.get_parent !== 'function') return;

    const popover = new Gtk.Popover();
    popover.set_parent(widget);
    popover.set_autohide(true);
    popover.set_has_arrow(true);

    const content = new Gtk.Box({
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 4,
    });

    const cpuLabel = new Gtk.Label({ label: "", xalign: 0 });
    const gpuLabel = new Gtk.Label({ label: "", xalign: 0 });
    const avgLabel = new Gtk.Label({ label: "", xalign: 0 });

    content.append(cpuLabel);
    content.append(gpuLabel);
    content.append(avgLabel);

    const updateLabels = () => {
      const temps = systemTemps.get() || { cpu: 0, gpu: 0, avg: 0, status: "normal" as const };
      const details = formatTempDetails(temps);
      cpuLabel.set_label(details.cpu);
      gpuLabel.set_label(details.gpu);
      avgLabel.set_label(details.avg);
    };

    updateLabels();

    let updateInterval: number | null = null;
    let isActive = true;

    const cleanup = () => {
      isActive = false;
      if (updateInterval !== null) {
        GLib.source_remove(updateInterval);
        updateInterval = null;
      }
    };

    updateInterval = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
      if (isActive) {
        try {
          if (popover.get_parent() !== null) {
            updateLabels();
            return true;
          }
        } catch (error) {
          // Popover might be destroyed, stop polling
        }
      }
      cleanup();
      return false;
    });

    popover.connect("closed", cleanup);
    popover.connect("notify::parent", () => {
      if (popover.get_parent() === null) {
        cleanup();
      }
    });

    popover.set_child(content);
    popover.popup();
  } catch (error) {
    console.error("Failed to show temperature details:", error);
  }
}
