import { createState } from "ags";
import { subprocess } from "ags/process";
import GLib from "gi://GLib";

const SCRIPT_PATH = `${GLib.get_home_dir()}/.local/bin/system-screenrecord`;

const [isRecordingState, setIsRecording] = createState(false);

let monitorProcess: any = null;

function startMonitoring() {
  if (monitorProcess) return;

  monitorProcess = subprocess(
    ["bash", "-c", `
      if pgrep -x wl-screenrec >/dev/null || pgrep -x wf-recorder >/dev/null; then
        last_state="1"
      else
        last_state="0"
      fi
      echo "$last_state"

      while true; do
        if pgrep -x wl-screenrec >/dev/null || pgrep -x wf-recorder >/dev/null; then
          current_state="1"
        else
          current_state="0"
        fi

        if [ "$current_state" != "$last_state" ]; then
          echo "$current_state"
          last_state="$current_state"
        fi

        sleep 0.2
      done
    `],
    (out) => {
      const recording = out.trim() === "1";
      setIsRecording(recording);
    },
    (err) => {
      console.error("[ScreenRecord] Monitor error:", err);
      monitorProcess = null;
      GLib.timeout_add(GLib.PRIORITY_DEFAULT, 1000, () => {
        startMonitoring();
        return false;
      });
    }
  );
}

startMonitoring();

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
  } catch (error) {
    console.error("Failed to toggle recording:", error);
  }
}

