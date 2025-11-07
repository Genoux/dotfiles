import { createState } from "ags";
import { timeout, interval } from "ags/time";
import GLib from "gi://GLib";
import Gio from "gi://Gio";

interface BrightnessState {
  brightness: number; // 0.0 to 1.0
}

const [isVisible, setIsVisible] = createState(false);
const [brightnessState, setBrightnessState] = createState<BrightnessState>({ brightness: 0 });
const [brightnessIcon, setBrightnessIcon] = createState("display-brightness-symbolic");

let hideTimeoutId = 0;
let isInitializing = true;
let lastBrightness = 0;

function getBrightnessIcon(brightness: number): string {
  if (brightness <= 0.1) {
    return "display-brightness-off-symbolic";
  } else if (brightness <= 0.3) {
    return "display-brightness-low-symbolic";
  } else if (brightness <= 0.7) {
    return "display-brightness-medium-symbolic";
  } else {
    return "display-brightness-high-symbolic";
  }
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

function updateBrightnessState(showOsd = false) {
  const brightness = readBrightness();
  setBrightnessState({ brightness });
  setBrightnessIcon(getBrightnessIcon(brightness));
  
  if (showOsd && !isInitializing) {
    showOSD();
  }
}

// Initial state
const initialBrightness = readBrightness();
lastBrightness = initialBrightness;
setBrightnessState({ brightness: initialBrightness });
setBrightnessIcon(getBrightnessIcon(initialBrightness));

// Poll for brightness changes (more reliable than file monitoring)
interval(100, () => {
  const currentBrightness = readBrightness();
  
  // Show OSD if brightness changed (even tiny changes)
  // Using very small threshold to catch all changes
  if (Math.abs(currentBrightness - lastBrightness) > 0.0001) {
    lastBrightness = currentBrightness;
    setBrightnessState({ brightness: currentBrightness });
    setBrightnessIcon(getBrightnessIcon(currentBrightness));
    
    if (!isInitializing) {
      showOSD();
    }
  }
});

// Disable initialization flag after a delay
timeout(300, () => {
  isInitializing = false;
});

export function showOSD() {
  setIsVisible(true);
  
  const currentTimeoutId = ++hideTimeoutId;
  
  timeout(2000, () => {
    if (currentTimeoutId === hideTimeoutId) {
      setIsVisible(false);
    }
  });
}

export { isVisible, brightnessState, brightnessIcon };

