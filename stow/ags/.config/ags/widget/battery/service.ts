import { createState } from "ags";
import { exec } from "ags/process";
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

  // Fallback: battery-level-100-charging-symbolic doesn't exist in most icon themes
  // Use battery-level-100-charged-symbolic or battery-full-charged-symbolic instead
  if (charging && index === 10) {
    return "battery-level-100-charged-symbolic";
  }

  return icons[index];
}

let battery: Battery.Device | null = null;
let hasBattery = false;

try {
  battery = Battery.get_default();
  // Check if battery actually exists by verifying a battery directory exists in /sys
  // Check for any BAT* device (BAT0, BAT1, etc.) to handle different laptop configurations
  if (battery !== null) {
    // Check for any battery device (BAT0, BAT1, etc.)
    const result = exec("sh -c 'ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -1 | grep -q . && echo yes || echo no'");
    hasBattery = result.trim() === "yes";
  } else {
    hasBattery = false;
  }
} catch (error) {
  console.log("No battery available:", error);
  hasBattery = false;
}

const [batteryState, setBatteryState] = createState<BatteryState>({
  percentage: Math.round((battery?.percentage || 0) * 100),
  charging: battery?.charging || false,
  available: hasBattery,
  icon: getBatteryIcon(Math.round((battery?.percentage || 0) * 100), battery?.charging || false),
});

function updateBatteryState() {
  if (!battery || !hasBattery) return;

  const percentage = Math.round((battery.percentage || 0) * 100);
  const charging = battery.charging || false;
  const icon = getBatteryIcon(percentage, charging);

  setBatteryState({
    percentage,
    charging,
    available: hasBattery,
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
    GLib.spawn_command_line_async('launch-or-focus "battop" "battop" "gnome-power-manager"');
  } catch (error) {
    console.error("Failed to launch battop:", error);
  }
}
