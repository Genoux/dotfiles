import { createState } from "ags";
import { subprocess } from "ags/process";
import { timeout } from "ags/time";
import GLib from "gi://GLib";
import Mpris from "gi://AstalMpris";

const CFG = "widget/cava/config/config";
let BAR_COUNT = 4;

try {
  const [_success, data] = GLib.file_get_contents(CFG);
  const text = new TextDecoder().decode(data);
  const match = text.match(/^\s*bars\s*=\s*(\d+)/m);
  if (match) {
    BAR_COUNT = parseInt(match[1], 10);
  }
} catch (e) {
  print(`Could not read cava config, using default BAR_COUNT: ${e}`);
}

// Initialize with minimum bar height (2) instead of 0 to prevent frozen appearance
export const [barsAccessor, setBars] = createState<number[]>(Array(BAR_COUNT).fill(2));

// Normalize bar values: ensure minimum of 2 (low bars) even when silent
// This prevents freezing and keeps bars visible at minimum height
const norm = (v: number) => {
  const normalized = Math.round(2 + (Math.min(v, 1000) / 1000) * 10);
  // Ensure minimum of 2 even when input is 0 (silence)
  return Math.max(2, normalized);
};

let updateTimeout: number | null = null;
let cavaProcess: any = null;
let isRestarting = false;
let isCavaRunning = false;

// Don't stop cava - keep it running to show low bars during silence
// This prevents freezing and keeps the visualizer responsive
function stopCava() {
  // Keep cava running - just let it show low bars when there's no sound
  // The visualizer will naturally show low values during silence
  // No need to kill the process or reset bars to 0
}

function startCava() {
  if (isRestarting || isCavaRunning) return;

  // Kill any orphaned cava processes before starting
  try {
    subprocess(["pkill", "-f", "cava -p widget/cava/config/config"], () => {}, () => {});
  } catch (e) {
    // Ignore error if no process to kill
  }

  try {
    cavaProcess = subprocess(
      ["cava", "-p", CFG],
      (out) => {
        if (updateTimeout) return;

        const nums = out
          .trim()
          .split(";")
          .map(Number)
          .filter((n) => !isNaN(n));

        if (nums.length >= BAR_COUNT) {
          // Normalize bars - ensures minimum of 2 even during silence
          const normalizedBars = nums.slice(0, BAR_COUNT).map(norm);
          setBars(normalizedBars);

          updateTimeout = setTimeout(() => {
            updateTimeout = null;
          }, 16) as any;
        } else if (nums.length > 0) {
          // If we get partial data, pad with minimum values
          const padded = [...nums.map(norm), ...Array(BAR_COUNT - nums.length).fill(2)];
          setBars(padded);
        }
      },
      (err) => {
        console.error("[Cava] Process error:", err);
        
        // Restart cava after it crashes
        if (!isRestarting) {
          isRestarting = true;
          console.log("[Cava] Restarting in 2 seconds...");
          
          // Set bars to minimum height (not 0) to prevent freezing
          setBars(Array(BAR_COUNT).fill(2));
          
          timeout(2000, () => {
            isRestarting = false;
            startCava();
          });
        }
      }
    );
    isCavaRunning = true;
  } catch (error) {
    console.error("[Cava] Failed to start:", error);
    
    if (!isRestarting) {
      isRestarting = true;
      timeout(5000, () => {
        isRestarting = false;
        startCava();
      });
    }
  }
}

// Start cava once and keep it running
// It will naturally show low bars during silence instead of freezing
// This keeps the visualizer responsive and prevents the "frozen" appearance
if (!isCavaRunning) {
  startCava();
}
