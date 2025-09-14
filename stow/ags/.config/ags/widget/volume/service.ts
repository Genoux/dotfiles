import Wp from "gi://AstalWp";
import { createBinding, createState } from "ags";
import GLib from "gi://GLib";

// AstalWp (WirePlumber) service for audio control
const wp = Wp.get_default();

// Get the default audio endpoint (usually speakers/headphones)
export const speaker = createBinding(wp.audio, "default_speaker");

// Direct volume and mute bindings for easier component use
export const speakerVolume = speaker((spk) => spk?.volume ?? 0);
export const speakerMuted = speaker((spk) => spk?.mute ?? false);

// Simple state that gets updated from both UI and system
export const [currentVolume, setCurrentVolume] = createState(0);
export const [currentMuted, setCurrentMuted] = createState(false);

// Derived state for icon - needs to react to both volume and mute changes
export const [currentIcon, setCurrentIcon] = createState("audio-volume-muted-symbolic");

// Debug initial state
console.log("[Volume Debug] Initial state - Volume: 0, Muted: false, Icon: audio-volume-muted-symbolic");

function clamp01(value: number): number {
  return Math.max(0, Math.min(1, value));
}

function syncFromSpeaker(spk: any) {
  if (!spk) return;
  const vol = clamp01(spk.volume ?? 0);
  const muted = !!(spk.mute ?? false);
  console.log(`[Volume Debug] syncFromSpeaker - Volume: ${vol}, Muted: ${muted}, Raw mute: ${spk.mute}`);
  setCurrentVolume(vol);
  setCurrentMuted(muted);
  setCurrentIcon(getVolumeIcon(vol, muted));
}

// Update icon when volume changes
currentVolume((vol) => {
  setCurrentIcon(getVolumeIcon(vol, currentMuted.get()));
  return vol;
});

// Update icon when mute changes  
currentMuted((muted) => {
  setCurrentIcon(getVolumeIcon(currentVolume.get(), muted));
  return muted;
});

// Wait for WirePlumber to be ready, then initialize
wp.connect("ready", () => {
  console.log("[Volume Debug] WirePlumber ready event fired");
  const spk = wp.audio.default_speaker;
  console.log("[Volume Debug] Default speaker:", spk);
  if (spk) {
    syncFromSpeaker(spk);
  } else {
    console.log("[Volume Debug] No default speaker found on ready");
  }
});

// Also listen for speaker changes and property updates
speaker((spk) => {
  if (!spk) {
    console.log("[Volume Debug] Speaker binding returned null");
    return spk;
  }

  console.log("[Volume Debug] Speaker binding updated, speaker:", spk);
  // Initial sync
  syncFromSpeaker(spk);

  // Listen for external changes
  spk.connect("notify::volume", () => {
    const newVol = clamp01(spk.volume ?? 0);
    console.log("[Volume Debug] Volume notify event, new volume:", newVol);
    setCurrentVolume(newVol);
  });

  spk.connect("notify::mute", () => {
    const newMute = !!(spk.mute ?? false);
    console.log("[Volume Debug] Mute notify event, new mute:", newMute);
    setCurrentMuted(newMute);
  });

  return spk;
});

// UI state
export const [volumePanelVisible, setVolumePanelVisible] = createState(false);

let __volumeVisible = false;

export function showVolumePanel() {
  __volumeVisible = true;
  print(`[VolumePanel] show`);
  setCurrentVolume(speakerVolume.get());
  setCurrentMuted(speakerMuted.get());
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
  return currentVolume.get();
}

export function setVolumeLevel(level: number) {
  const spk = wp.audio.default_speaker;
  if (spk) {
    const clampedLevel = clamp01(level);
    let newMuteState = !!spk.mute;
    
    // If setting volume above 0 while muted, unmute first
    if (clampedLevel > 0 && spk.mute) {
      spk.set_mute(false);
      setCurrentMuted(false);
      newMuteState = false;
    }
    
    spk.set_volume(clampedLevel);
    // Also update our state immediately for UI responsiveness
    setCurrentVolume(clampedLevel);
    
    // Force icon update immediately for responsive UI using correct mute state
    const newIcon = getVolumeIcon(clampedLevel, newMuteState);
    setCurrentIcon(newIcon);
  }
}

export function toggleMute() {
  const spk = wp.audio.default_speaker;
  if (spk) {
    const currentMute = !!spk.mute;
    const newMute = !currentMute;
    
    // Update local state immediately for UI responsiveness
    setCurrentMuted(newMute);
    
    // Force icon update immediately
    const newIcon = getVolumeIcon(currentVolume.get(), newMute);
    setCurrentIcon(newIcon);
    
    // Try the mute operation
    try {
      spk.set_mute(newMute);
    } catch (error) {
      console.log("[Volume] Error setting mute:", error);
      // Revert local state on error
      setCurrentMuted(currentMute);
    }
  }
}

export function isMuted(): boolean {
  return currentMuted.get();
}

// Icon helper function
export function getVolumeIcon(volume?: number, muted?: boolean): string {
  const vol = volume !== undefined ? volume : currentVolume.get();
  const isMute = muted !== undefined ? muted : currentMuted.get();
  
  if (isMute) {
    return "audio-volume-muted-symbolic";
  } else if (vol <= 0) {
    return "audio-volume-low-symbolic";
  } else if (vol > 0.6) {
    return "audio-volume-high-symbolic";
  } else if (vol > 0.3) {
    return "audio-volume-medium-symbolic";
  } else {
    return "audio-volume-low-symbolic";
  }
}

export function openVolumeManager() {
  try {
      GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-wiremix`);
  } catch (error) {
    console.error("Failed to launch launch-wiremix:", error);
  }
}