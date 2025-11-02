import Wp from "gi://AstalWp";
import { createState } from "ags";
import GLib from "gi://GLib";

const wp = Wp.get_default();

function getVolumeIcon(volume: number, muted: boolean): string {
  if (muted) {
    return "audio-volume-muted-symbolic";
  } else if (volume <= 0) {
    return "audio-volume-low-symbolic";
  } else if (volume > 0.6) {
    return "audio-volume-high-symbolic";
  } else if (volume > 0.3) {
    return "audio-volume-medium-symbolic";
  } else {
    return "audio-volume-low-symbolic";
  }
}

function updateIcon(): string {
  try {
    const spk = wp.audio.default_speaker;
    if (spk) {
      return getVolumeIcon(spk.volume, spk.mute);
    }
    return "audio-volume-high-symbolic";
  } catch (error) {
    console.error("Volume update error:", error);
    return "audio-volume-high-symbolic";
  }
}

// Use reactive state with signal-based updates instead of polling
export const [currentIcon, setCurrentIcon] = createState(updateIcon());

// Track speaker handlers to prevent duplicate connections
let speakerHandlerIds: number[] = [];

// Setup signal handlers for reactive updates
function setupSpeakerSignals() {
  // Disconnect old handlers
  const oldSpk = wp.audio.default_speaker;
  if (oldSpk && speakerHandlerIds.length > 0) {
    speakerHandlerIds.forEach((id) => oldSpk.disconnect(id));
    speakerHandlerIds = [];
  }

  // Connect new handlers
  const spk = wp.audio.default_speaker;
  if (spk) {
    speakerHandlerIds = [
      spk.connect("notify::volume", () => setCurrentIcon(updateIcon())),
      spk.connect("notify::mute", () => setCurrentIcon(updateIcon())),
    ];
  }
}

// Listen for default speaker property changes
wp.audio.connect("notify::default-speaker", () => {
  setCurrentIcon(updateIcon());
  setupSpeakerSignals();
});

// Setup initial speaker signals
setupSpeakerSignals();

export function openVolumeManager() {
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-wiremix`);
  } catch (error) {
    console.error("Failed to launch launch-wiremix:", error);
  }
}
