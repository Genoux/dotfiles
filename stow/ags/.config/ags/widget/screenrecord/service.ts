import { createState, onCleanup } from "ags";
import { subprocess, exec } from "ags/process";
import GLib from "gi://GLib";

const SCRIPT_PATH = `${GLib.get_home_dir()}/.local/bin/system-screenrecord`;

const [isRecordingState, setIsRecording] = createState(false);

let monitorProcess: any = null;

let restartCount = 0;
const MAX_RESTARTS = 3;

function stopMonitoring() {
  if (monitorProcess) {
    try {
      monitorProcess.kill();
    } catch (e) {
      console.error("[ScreenRecord] Error killing monitor process:", e);
    }
    monitorProcess = null;
  }
  
  // Kill any orphaned monitoring processes (safety net)
  try {
    exec(["pkill", "-f", "inotifywait.*screenrecording"]);
  } catch (e) {
    // Ignore if no process to kill
  }
}

function startMonitoring() {
  // Kill any existing process before starting new one
  stopMonitoring();

  // EVENT-DRIVEN: Watch the Videos directory for new recording files
  // Much more efficient than polling pgrep every N seconds
  monitorProcess = subprocess(
    ["bash", "-c", `
      VIDEOS_DIR="\${XDG_VIDEOS_DIR:-$HOME/Videos}"
      mkdir -p "\${VIDEOS_DIR}"
      
      # Initial state check
      if pgrep -x wl-screenrec >/dev/null 2>&1 || pgrep -x wf-recorder >/dev/null 2>&1; then
        echo "1"
        last_state="1"
      else
        echo "0"
        last_state="0"
      fi

      # Watch Videos directory for screenrecording file creation/modification
      # When recording starts, a file is created; when it stops, file is closed
      inotifywait -m -e create,delete,close_write "\${VIDEOS_DIR}" 2>/dev/null | while read -r dir event file; do
        # Only react to screenrecording files
        if [[ "$file" == screenrecording-* ]]; then
          # On recording file event, check if recorder is running
          if pgrep -x wl-screenrec >/dev/null 2>&1 || pgrep -x wf-recorder >/dev/null 2>&1; then
            current_state="1"
          else
            current_state="0"
          fi

          if [ "$current_state" != "$last_state" ]; then
            echo "$current_state"
            last_state="$current_state"
          fi
        fi
      done
    `],
    (out) => {
      const recording = out.trim() === "1";
      console.log(`[ScreenRecord] State changed: ${recording ? "Recording" : "Stopped"}`);
      setIsRecording(recording);
      restartCount = 0;
    },
    (err) => {
      console.error("[ScreenRecord] Monitor error:", err);
      monitorProcess = null;

      restartCount++;
      if (restartCount <= MAX_RESTARTS) {
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
          startMonitoring();
          return false;
        });
      } else {
        console.error("[ScreenRecord] Max restarts reached, giving up");
      }
    }
  );
}

startMonitoring();

// Cleanup on AGS restart
onCleanup(() => {
  stopMonitoring();
});

export const isRecording = isRecordingState;

export type RecordScope = "region" | "output" | "fullscreen";

// Synchronously check if recording is active right now
export function isCurrentlyRecording(): boolean {
  try {
    const [success, stdout] = GLib.spawn_command_line_sync("pgrep -x wl-screenrec");
    if (success && stdout && new TextDecoder().decode(stdout).trim() !== "") {
      return true;
    }
    
    const [success2, stdout2] = GLib.spawn_command_line_sync("pgrep -x wf-recorder");
    if (success2 && stdout2 && new TextDecoder().decode(stdout2).trim() !== "") {
      return true;
    }
    
    return false;
  } catch {
    return false;
  }
}

export function toggleRecording(scope: RecordScope = "region", withAudio = false) {
  try {
    const audioParam = withAudio ? " audio" : "";
    GLib.spawn_command_line_async(`${SCRIPT_PATH} ${scope}${audioParam}`);
    
    // Check state immediately after 500ms (give process time to start)
    GLib.timeout_add(GLib.PRIORITY_DEFAULT, 500, () => {
      const nowRecording = isCurrentlyRecording();
      setIsRecording(nowRecording);
      return false;
    });
  } catch (error) {
    console.error("Failed to toggle recording:", error);
  }
}

