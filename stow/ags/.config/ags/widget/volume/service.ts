import Wp from "gi://AstalWp";
import { createPoll } from "ags/time";
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

// Poll volume state every 200ms for responsive updates
export const currentIcon = createPoll(
  "audio-volume-high-symbolic",
  200,
  () => {
    try {
      const spk = wp.audio.default_speaker;
      if (spk) {
        const volume = spk.volume;
        const muted = spk.mute;
        const icon = getVolumeIcon(volume, muted);
        return icon;
      }
      return "audio-volume-high-symbolic";
    } catch (error) {
      console.error("Volume poll error:", error);
      return "audio-volume-high-symbolic";
    }
  }
);

export function openVolumeManager() {
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-wiremix`);
  } catch (error) {
    console.error("Failed to launch launch-wiremix:", error);
  }
}