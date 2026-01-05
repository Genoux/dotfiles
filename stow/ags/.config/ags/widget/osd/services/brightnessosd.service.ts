import { createState } from "ags";
import { exec, execAsync, subprocess } from "ags/process";
import { timeout } from "ags/time";
import { createOSDService } from "../../../services/osd";

const osd = createOSDService(2000);

const [brightnessState, setBrightnessState] = createState({ brightness: 0 });
const [brightnessIcon, setBrightnessIcon] = createState("display-brightness-symbolic");

let lastBrightness = 0;
let hasBacklight = false;
let isReading = false;
let consecutiveErrors = 0;
const MAX_ERRORS = 5;

try {
  const result = exec(
    "sh -c 'ls -d /sys/class/backlight/* 2>/dev/null | head -1 | grep -q . && echo yes || echo no'"
  );
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

async function readBrightnessAsync(): Promise<number> {
  try {
    const currentStr = await execAsync("brightnessctl get");
    const maxStr = await execAsync("brightnessctl max");

    const current = parseInt(currentStr.trim());
    const max = parseInt(maxStr.trim());

    if (isNaN(current) || isNaN(max) || max === 0) {
      throw new Error("Invalid brightness values");
    }

    consecutiveErrors = 0;
    return current / max;
  } catch (error) {
    consecutiveErrors++;
    if (consecutiveErrors <= 3) {
      console.error("Failed to read brightness:", error);
    }
    if (consecutiveErrors === MAX_ERRORS) {
      console.error(`Brightness polling failed ${MAX_ERRORS} times, may indicate hardware issue`);
    }
    return lastBrightness;
  }
}

if (hasBacklight) {
  readBrightnessAsync().then((initialBrightness) => {
    lastBrightness = initialBrightness;
    setBrightnessState({ brightness: initialBrightness });
    setBrightnessIcon(getBrightnessIcon(initialBrightness));
  });

  // EVENT-DRIVEN: Monitor brightness changes via udevadm (only triggers on actual changes)
  // Replaces 250ms polling that wasted CPU with 8 process spawns/second
  subprocess(
    ["sh", "-c", "udevadm monitor --subsystem-match=backlight | while read line; do brightnessctl get; done"],
    async (out: string) => {
      try {
        const current = parseInt(out.trim());
        const maxStr = await execAsync("brightnessctl max");
        const max = parseInt(maxStr.trim());

        if (!isNaN(current) && !isNaN(max) && max > 0) {
          const brightness = current / max;
          const brightnessChanged = Math.abs(brightness - lastBrightness) > 0.0001;

          if (brightnessChanged) {
            lastBrightness = brightness;
            setBrightnessState({ brightness });
            setBrightnessIcon(getBrightnessIcon(brightness));

            if (!osd.initializing) {
              osd.show();
            }
          }
        }
      } catch (error) {
        console.error("Failed to update brightness:", error);
      }
    },
    (err: string) => {
      console.error("Brightness monitor error:", err);
    }
  );

  timeout(300, () => {
    osd.finishInitialization();
  });
} else {
  console.log("Brightness OSD disabled: no backlight detected (desktop system)");
}

export { osd, brightnessState, brightnessIcon };
