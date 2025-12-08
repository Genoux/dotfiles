import { createState } from "ags";
import { subprocess } from "ags/process";
import { timeout } from "ags/time";
import GLib from "gi://GLib";

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

export const [barsAccessor, setBars] = createState<number[]>(Array(BAR_COUNT).fill(0));

const norm = (v: number) => Math.round(2 + (Math.min(v, 1000) / 1000) * 10);

let updateTimeout: number | null = null;
let cavaProcess: any = null;
let isRestarting = false;

function startCava() {
  if (isRestarting) return;
  
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
          setBars(nums.slice(0, BAR_COUNT).map(norm));

          updateTimeout = setTimeout(() => {
            updateTimeout = null;
          }, 16) as any;
        }
      },
      (err) => {
        console.error("[Cava] Process error:", err);
        
        // Restart cava after it crashes
        if (!isRestarting) {
          isRestarting = true;
          console.log("[Cava] Restarting in 2 seconds...");
          
          // Reset bars to zero
          setBars(Array(BAR_COUNT).fill(0));
          
          timeout(2000, () => {
            isRestarting = false;
            startCava();
          });
        }
      }
    );
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

// Start cava subprocess
startCava();
