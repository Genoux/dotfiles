import { createState } from "ags";
import { subprocess } from "ags/process";
import { timeout } from "ags/time";
import GLib from "gi://GLib";
import Mpris from "gi://AstalMpris";
import { getActivePlayer } from "../mediaplayer/service";

const CFG = "widget/cava/config/config";

// ─── Edit these to tune the visualization ─────────────────────
const CAVA_SETTINGS = {
  silenceThreshold: 2, // raw value 0-1000; below this = flat. Lower = more sensitive to quiet sound
  sensitivityMultiplier: 1.25, // boost bar heights (1 = normal, >1 = more responsive)
  lerpFactor: 0.35, // how fast bars chase audio (1=instant, lower=smoother)
  barMin: 2, // min bar height when sound detected
  barMax: 10, // max bar height at peak (cava outputs 0-1000)
  lerpIntervalMs: 17, // animation frame rate (~60fps)
} as const;
// ──────────────────────────────────────────────────────────────

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

const norm = (v: number) => {
  if (v < CAVA_SETTINGS.silenceThreshold) return 0;
  const raw = CAVA_SETTINGS.barMin + (Math.min(v, 1000) / 1000) * CAVA_SETTINGS.barMax;
  return Math.round(Math.min(12, raw * CAVA_SETTINGS.sensitivityMultiplier));
};
let targetBars = Array(BAR_COUNT).fill(0);
let currentBars = Array(BAR_COUNT).fill(0);

function lerpTick(): boolean {
  const next = currentBars.map((c, i) => {
    const t = targetBars[i] ?? 0;
    return Math.round(c + (t - c) * CAVA_SETTINGS.lerpFactor);
  });
  if (next.some((v, i) => v !== currentBars[i])) {
    currentBars = next;
    setBars([...next]);
  }
  return true; // keep running
}

GLib.timeout_add(GLib.PRIORITY_DEFAULT, CAVA_SETTINGS.lerpIntervalMs, () => lerpTick());

let cavaProcess: any = null;
let isRestarting = false;
let isCavaRunning = false;

function stopCava() {
  if (isCavaRunning) {
    console.log("[Cava] Stopping - no active media players");
    isCavaRunning = false;

    targetBars = Array(BAR_COUNT).fill(0);

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

  try {
    cavaProcess = subprocess(
      ["cava", "-p", CFG],
      (out) => {
        if (!isCavaRunning) return;
        if (!hasDisplayedPlayerPlaying()) return; // ignore output when paused, decay runs separately

        const nums = out
          .trim()
          .split(";")
          .map(Number)
          .filter((n) => !isNaN(n));

        if (nums.length >= BAR_COUNT) {
          targetBars = nums.slice(0, BAR_COUNT).map(norm);
        }
      },
      (err) => {
        console.error("[Cava] Process error:", err);
        
        // Restart cava after it crashes
        if (!isRestarting) {
          isRestarting = true;
          console.log("[Cava] Restarting in 2 seconds...");
          
          targetBars = Array(BAR_COUNT).fill(0);
          currentBars = Array(BAR_COUNT).fill(0);
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

// Keep cava running whenever we have a displayed player - only stop when no players at all.
// This avoids the 1.5s Pulse connection delay when resuming playback.
const mpris = Mpris.get_default();

function hasDisplayedPlayer(): boolean {
  return !!getActivePlayer();
}

function hasDisplayedPlayerPlaying(): boolean {
  const player = getActivePlayer();
  return !!player && player.playbackStatus === Mpris.PlaybackStatus.PLAYING;
}

// Start cava when we have a player; stop only when no players exist
function updateCavaState() {
  if (hasDisplayedPlayer()) {
    if (!isCavaRunning) {
      startCava();
    } else if (!hasDisplayedPlayerPlaying()) {
      targetBars = Array(BAR_COUNT).fill(0);
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
