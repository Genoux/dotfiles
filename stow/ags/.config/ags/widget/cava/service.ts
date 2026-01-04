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

export const [barsAccessor, setBars] = createState<number[]>(Array(BAR_COUNT).fill(0));

const norm = (v: number) => Math.round(2 + (Math.min(v, 1000) / 1000) * 10);

let updateTimeout: number | null = null;
let cavaProcess: any = null;
let isRestarting = false;
let isCavaRunning = false;

function stopCava() {
  if (isCavaRunning) {
    console.log("[Cava] Stopping - no active media players");
    isCavaRunning = false;

    // The subprocess will check isCavaRunning and exit on next output
    // Reset visual state immediately
    setBars(Array(BAR_COUNT).fill(0));

    // Clear the process reference after a delay to allow cleanup
    if (cavaProcess) {
      const oldProcess = cavaProcess;
      cavaProcess = null;

      // Kill the process using pkill
      try {
        subprocess(["pkill", "-f", "cava -p widget/cava/config/config"], () => {}, () => {});
      } catch (e) {
        console.error("[Cava] Error killing process:", e);
      }
    }
  }
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
    console.log("[Cava] Starting - media player active");
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

// Helper to check if there's an active media player
const mpris = Mpris.get_default();

function hasActivePlayer(): boolean {
  return mpris.players.some((p) => {
    // Only run cava when media is actively PLAYING (not paused)
    return p.playbackStatus === Mpris.PlaybackStatus.PLAYING && p.canControl;
  });
}

// Start/stop cava based on media player state
function updateCavaState() {
  if (hasActivePlayer()) {
    if (!isCavaRunning) {
      startCava();
    }
  } else {
    if (isCavaRunning) {
      stopCava();
    }
  }
}

// Watch for player changes
mpris.connect("notify::players", updateCavaState);

// Watch for player state changes on existing players
const setupPlayerWatchers = () => {
  mpris.players.forEach((player) => {
    player.connect("notify::playback-status", updateCavaState);
  });
};

setupPlayerWatchers();
mpris.connect("notify::players", setupPlayerWatchers);

// Initial state check
updateCavaState();
