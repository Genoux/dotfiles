import { createState } from "ags";
import { subprocess, exec } from "ags/process";
import { Gtk } from "ags/gtk4";
import GLib from "gi://GLib";

type PrivacyState = {
  webcam: boolean;
  mic: boolean;
  screenrecord: boolean;
};

const [privacyState, setPrivacyState] = createState<PrivacyState>({
  webcam: false,
  mic: false,
  screenrecord: false,
});

let monitorProcess: any = null;
let restartCount = 0;
const MAX_RESTARTS = 3;

function startMonitoring() {
  if (monitorProcess) return;

  monitorProcess = subprocess(
    ["bash", "-c", `
      check_webcam() {
        # Check if any video device is being used
        for dev in /dev/video*; do
          [ -e "$dev" ] && fuser "$dev" 2>/dev/null | grep -q . && echo 1 && return
        done
        echo 0
      }

      check_mic() {
        if command -v pactl &>/dev/null; then
          # Check for source-outputs recording from real mics (alsa_input devices)
          pactl list source-outputs 2>/dev/null | grep -q 'target.object = "alsa_input' && echo 1 && return
        fi
        echo 0
      }

      check_webcam_mic() {
        # If webcam is active, check if it has a built-in mic that could be used
        # This is a privacy precaution - if webcam is on, mic might be too
        # Takes webcam state as argument to avoid double-checking
        local webcam_active="$1"
        if [ "$webcam_active" = "1" ] && command -v pactl &>/dev/null; then
          # Check if webcam has an audio source (built-in mic)
          pactl list sources short 2>/dev/null | grep -qi "webcam\|camera\|video" && echo 1 && return
        fi
        echo 0
      }

      check_screenrecord() {
        # Check for exact process names first
        pgrep -x "wl-screenrec" >/dev/null 2>&1 && echo 1 && return
        pgrep -x "wf-recorder" >/dev/null 2>&1 && echo 1 && return
        pgrep -x "obs" >/dev/null 2>&1 && echo 1 && return
        pgrep -x "gpu-screen-recorder" >/dev/null 2>&1 && echo 1 && return
        pgrep -x "kooha" >/dev/null 2>&1 && echo 1 && return
        # Also check for processes with full paths (more specific)
        pgrep -f "^[^ ]*wl-screenrec" >/dev/null 2>&1 && echo 1 && return
        pgrep -f "^[^ ]*wf-recorder" >/dev/null 2>&1 && echo 1 && return
        echo 0
      }

      last_webcam=""
      last_mic=""
      last_screen=""
      first_run=true

      while true; do
        cur_webcam=$(check_webcam)
        cur_mic=$(check_mic)
        cur_webcam_mic=$(check_webcam_mic "$cur_webcam")
        cur_screen=$(check_screenrecord)

        # Combine regular mic check with webcam mic check
        # Show mic if either regular mic is active OR webcam with mic is active
        if [ "$cur_mic" = "1" ] || [ "$cur_webcam_mic" = "1" ]; then
          final_mic="1"
        else
          final_mic="0"
        fi

        # Always output on first run to set initial state
        if [ "$first_run" = true ] || [ "$cur_webcam" != "$last_webcam" ] || [ "$final_mic" != "$last_mic" ] || [ "$cur_screen" != "$last_screen" ]; then
          echo "$cur_webcam:$final_mic:$cur_screen"
          last_webcam="$cur_webcam"
          last_mic="$final_mic"
          last_screen="$cur_screen"
          first_run=false
        fi

        sleep 1
      done
    `],
    (out) => {
      const [webcam, mic, screenrecord] = out.trim().split(":");
      setPrivacyState({
        webcam: webcam === "1",
        mic: mic === "1",
        screenrecord: screenrecord === "1",
      });
      restartCount = 0;
    },
    (err) => {
      console.error("[Privacy] Monitor error:", err);
      monitorProcess = null;

      restartCount++;
      if (restartCount <= MAX_RESTARTS) {
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, 2000, () => {
          startMonitoring();
          return false;
        });
      } else {
        console.error("[Privacy] Max restarts reached");
      }
    }
  );
}

startMonitoring();

export const privacy = privacyState;

export const isWebcamActive = privacyState((s) => s.webcam);
export const isMicActive = privacyState((s) => s.mic);
export const isScreenRecordActive = privacyState((s) => s.screenrecord);
export const isAnyActive = privacyState((s) => s.webcam || s.mic || s.screenrecord);

export function getMicApps(): string[] {
  try {
    const out = exec(["bash", "-c", `pactl list source-outputs 2>/dev/null | grep -B20 'target.object = "alsa_input' | grep 'application.name' | sed 's/.*= "\\(.*\\)"/\\1/' | sort -u`]);
    return out.trim().split("\n").filter(Boolean);
  } catch {
    return [];
  }
}

export function getWebcamApps(): string[] {
  try {
    const out = exec(["bash", "-c", `for dev in /dev/video*; do fuser "$dev" 2>/dev/null; done | xargs -r ps -o comm= -p 2>/dev/null | sort -u`]);
    return out.trim().split("\n").filter(Boolean);
  } catch {
    return [];
  }
}

export function getScreenRecordApps(): string[] {
  try {
    const apps: string[] = [];
    const checks = ["wl-screenrec", "wf-recorder", "obs", "gpu-screen-recorder", "kooha"];
    for (const app of checks) {
      try {
        exec(["pgrep", "-x", app]);
        apps.push(app);
      } catch {}
    }
    return apps;
  } catch {
    return [];
  }
}

export function showPrivacyDetails(widget: any, getApps: () => string[]) {
  try {
    if (!widget || typeof widget.get_parent !== "function") return;

    const popover = new Gtk.Popover();
    popover.set_parent(widget);
    popover.set_autohide(true);
    popover.set_has_arrow(true);

    const content = new Gtk.Box({
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 2,
    });
    content.add_css_class("privacy-popover");

    const apps = getApps();
    const appList = apps.length > 0 ? apps : ["Unknown"];
    appList.forEach((app) => {
      const appLabel = new Gtk.Label({ label: app, xalign: 0 });
      content.append(appLabel);
    });

    popover.set_child(content);
    popover.popup();
  } catch (error) {
    console.error("Failed to show privacy details:", error);
  }
}

