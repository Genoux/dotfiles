import { createState } from "ags";
import { exec } from "ags/process";
import { timeout, interval } from "ags/time";
import GLib from "gi://GLib";
import { createOSDService } from "../../../services/osd";

const osd = createOSDService(2000);

const [brightnessState, setBrightnessState] = createState({ brightness: 0 });
const [brightnessIcon, setBrightnessIcon] = createState("display-brightness-symbolic");

let lastBrightness = 0;
let hasBacklight = false;

// Check if backlight is available (laptop detection)
try {
  const result = exec("sh -c 'ls -d /sys/class/backlight/* 2>/dev/null | head -1 | grep -q . && echo yes || echo no'");
  hasBacklight = result.trim() === "yes";
} catch (error) {
  console.log("No backlight available:", error);
  hasBacklight = false;
}

function getBrightnessIcon(brightness: number): string {
  if (brightness <= 0.1) return "display-brightness-off-symbolic";
  if (brightness <= 0.3) return "display-brightness-low-symbolic";
  if (brightness <= 0.7) return "display-brightness-medium-symbolic";
  return "display-brightness-high-symbolic";
}

function readBrightness(): number {
  try {
    const [ok1, stdout1] = GLib.spawn_command_line_sync("brightnessctl get");
    if (!ok1 || !stdout1) throw new Error("Failed to run 'brightnessctl get'");
    const current = parseInt(new TextDecoder().decode(stdout1).trim());

    const [ok2, stdout2] = GLib.spawn_command_line_sync("brightnessctl max");
    if (!ok2 || !stdout2) throw new Error("Failed to run 'brightnessctl max'");
    const max = parseInt(new TextDecoder().decode(stdout2).trim());

    if (isNaN(current) || isNaN(max) || max === 0) return 0;
    return current / max;
  } catch (error) {
    console.error("Failed to read brightness:", error);
    return 0;
  }
}

// Only initialize if backlight is available
if (hasBacklight) {
  lastBrightness = readBrightness();
  setBrightnessState({ brightness: lastBrightness });
  setBrightnessIcon(getBrightnessIcon(lastBrightness));

  interval(100, () => {
    const currentBrightness = readBrightness();
    const brightnessChanged = Math.abs(currentBrightness - lastBrightness) > 0.0001;

    if (brightnessChanged) {
      lastBrightness = currentBrightness;
      setBrightnessState({ brightness: currentBrightness });
      setBrightnessIcon(getBrightnessIcon(currentBrightness));

      if (!osd.initializing) {
        osd.show();
      }
    }
  });

  timeout(300, () => {
    osd.finishInitialization();
  });
} else {
  console.log("Brightness OSD disabled: no backlight detected (desktop system)");
}

export { osd, brightnessState, brightnessIcon };

