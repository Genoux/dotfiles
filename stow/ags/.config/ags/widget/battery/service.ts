import { createState, createBinding } from "ags";
import Battery from "gi://AstalBattery";
import GLib from "gi://GLib";

export interface BatteryState {
  percentage: number;
  charging: boolean;
  available: boolean;
  icon: string;
}

const batteryIcons = {
  charging: [
    "battery-level-0-charging-symbolic",
    "battery-level-10-charging-symbolic",
    "battery-level-20-charging-symbolic",
    "battery-level-30-charging-symbolic",
    "battery-level-40-charging-symbolic",
    "battery-level-50-charging-symbolic",
    "battery-level-60-charging-symbolic",
    "battery-level-70-charging-symbolic",
    "battery-level-80-charging-symbolic",
    "battery-level-90-charging-symbolic",
    "battery-level-100-charging-symbolic",
  ],
  discharging: [
    "battery-level-0-symbolic",
    "battery-level-10-symbolic",
    "battery-level-20-symbolic",
    "battery-level-30-symbolic",
    "battery-level-40-symbolic",
    "battery-level-50-symbolic",
    "battery-level-60-symbolic",
    "battery-level-70-symbolic",
    "battery-level-80-symbolic",
    "battery-level-90-symbolic",
    "battery-level-100-symbolic",
  ],
};

function getBatteryIcon(percentage: number, charging: boolean): string {
  const icons = charging ? batteryIcons.charging : batteryIcons.discharging;
  const index = Math.min(Math.floor(percentage / 10), 10);
  return icons[index];
}

let battery: Battery.Device | null = null;
let hasBattery = false;

try {
  battery = Battery.get_default();
  hasBattery = battery !== null;
} catch (error) {
  console.log("No battery available");
}

const [batteryState, setBatteryState] = createState<BatteryState>({
  percentage: battery?.percentage || 0,
  charging: battery?.charging || false,
  available: hasBattery,
  icon: getBatteryIcon(battery?.percentage || 0, battery?.charging || false),
});

function updateBatteryState() {
  if (!battery) return;

  const percentage = Math.round((battery.percentage || 0) * 100);
  const charging = battery.charging || false;
  const icon = getBatteryIcon(percentage, charging);

  setBatteryState({
    percentage,
    charging,
    available: true,
    icon,
  });
}

if (battery) {
  // Update on battery property changes
  battery.connect("notify::percentage", updateBatteryState);
  battery.connect("notify::charging", updateBatteryState);

  // Initial update
  updateBatteryState();
}

export const batteryStateAccessor = batteryState;
export const hasBatteryAvailable = hasBattery;

export function openBattop() {
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-battop`);
  } catch (error) {
    console.error("Failed to launch battop:", error);
  }
}

