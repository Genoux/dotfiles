import Wp from "gi://AstalWp";
import { createBinding, createState } from "ags";

// AstalWp (WirePlumber) service for audio control
const wp = Wp.get_default();

// Export the raw service in case components need direct access
export const audioService = wp;

// Get the default audio endpoint (usually speakers/headphones)
export const speaker = createBinding(wp, "defaultSpeaker");
export const microphone = createBinding(wp, "defaultMicrophone");

// Visibility state for the volume panel
export const [volumePanelVisible, setVolumePanelVisible] = createState(false);

let __volumeVisible = false;

export function showVolumePanel() {
  __volumeVisible = true;
  print(`[VolumePanel] show`);
  setVolumePanelVisible(true);
}

export function hideVolumePanel() {
  __volumeVisible = false;
  print(`[VolumePanel] hide`);
  setVolumePanelVisible(false);
}

export function toggleVolumePanel() {
  __volumeVisible = !__volumeVisible;
  print(`[VolumePanel] toggle -> ${__volumeVisible ? "true" : "false"}`);
  setVolumePanelVisible(__volumeVisible);
}

// Helper functions for volume control
export function getVolumeLevel(): number {
  const spk = wp.defaultSpeaker;
  return spk ? spk.volume : 0;
}

export function setVolumeLevel(level: number) {
  const spk = wp.defaultSpeaker;
  if (spk) {
    spk.set_volume(Math.max(0, Math.min(1, level)));
  }
}

export function toggleMute() {
  const spk = wp.defaultSpeaker;
  if (spk) {
    spk.set_mute(!spk.mute);
  }
}

export function isMuted(): boolean {
  const spk = wp.defaultSpeaker;
  return spk ? spk.mute : false;
}

// Icon helper function
export function getVolumeIcon(): string {
  const spk = wp.defaultSpeaker;
  if (!spk || spk.mute) {
    return "audio-volume-muted-symbolic";
  }
  
  const volume = spk.volume;
  if (volume > 0.6) {
    return "audio-volume-high-symbolic";
  } else if (volume > 0.3) {
    return "audio-volume-medium-symbolic";
  } else if (volume > 0) {
    return "audio-volume-low-symbolic";
  } else {
    return "audio-volume-muted-symbolic";
  }
}