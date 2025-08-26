import Wp from "gi://AstalWp";
import { createBinding, createState } from "ags";

// AstalWp (WirePlumber) service for audio control
const wp = Wp.get_default();

// Export the raw service in case components need direct access
export const audioService = wp;

// Get the default audio endpoint (usually speakers/headphones)
export const speaker = createBinding(wp.audio, "default_speaker");
export const microphone = createBinding(wp.audio, "default_microphone");

// Direct volume and mute bindings for easier component use
export const speakerVolume = speaker((spk) => spk?.volume ?? 0);
export const speakerMuted = speaker((spk) => spk?.mute ?? false);

// Simple state that gets updated from both UI and system
export const [currentVolume, setCurrentVolume] = createState(0);
export const [currentMuted, setCurrentMuted] = createState(false);

// Derived state for icon - needs to react to both volume and mute changes
export const [currentIcon, setCurrentIcon] = createState("audio-volume-muted-symbolic");

function clamp01(value: number): number {
  return Math.max(0, Math.min(1, value));
}

function syncFromSpeaker(spk: any) {
  if (!spk) return;
  const vol = clamp01(spk.volume ?? 0);
  const muted = !!(spk.mute ?? false);
  console.log("[Volume] syncFromSpeaker -> vol:", vol, "muted:", muted);
  setCurrentVolume(vol);
  setCurrentMuted(muted);
  setCurrentIcon(getVolumeIcon(vol, muted));
}

// Update icon when volume changes
currentVolume((vol) => {
  const newIcon = getVolumeIcon(vol, currentMuted.get());
  console.log("[Volume] Volume changed to:", vol, "updating icon to:", newIcon);
  setCurrentIcon(newIcon);
  return vol;
});

// Update icon when mute changes  
currentMuted((muted) => {
  const newIcon = getVolumeIcon(currentVolume.get(), muted);
  console.log("[Volume] Mute state changed to:", muted, "updating icon to:", newIcon);
  setCurrentIcon(newIcon);
  return muted;
});

// Wait for WirePlumber to be ready, then initialize
wp.connect("ready", () => {
  console.log("[Volume] WirePlumber is ready");
  const spk = wp.audio.default_speaker;
  if (!spk) {
    console.log("[Volume] No default speaker at ready - will rely on binding");
    return;
  }
  console.log("[Volume] Found speaker at ready, raw volume:", spk.volume, "raw mute:", spk.mute);
  syncFromSpeaker(spk);
});

// Also listen for speaker changes and property updates
speaker((spk) => {
  console.log("[Volume] speaker() binding fired. has speaker:", !!spk);
  if (!spk) return spk;

  // Initial sync
  syncFromSpeaker(spk);

  // Listen for external changes
  spk.connect("notify::volume", () => {
    console.log("[Volume] notify::volume ->", spk.volume);
    setCurrentVolume(clamp01(spk.volume ?? 0));
  });

  spk.connect("notify::mute", () => {
    const newMuteState = !!(spk.mute ?? false);
    console.log("[Volume] notify::mute ->", spk.mute, "setting currentMuted to:", newMuteState);
    setCurrentMuted(newMuteState);
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
      console.log("[Volume] Auto-unmuting because volume set to:", clampedLevel);
      spk.set_mute(false);
      setCurrentMuted(false);
      newMuteState = false;
    }
    
    spk.set_volume(clampedLevel);
    // Also update our state immediately for UI responsiveness
    setCurrentVolume(clampedLevel);
    
    // Force icon update immediately for responsive UI using correct mute state
    const newIcon = getVolumeIcon(clampedLevel, newMuteState);
    console.log("[Volume] setVolumeLevel - forcing icon update to:", newIcon, "volume:", clampedLevel, "muted:", newMuteState);
    setCurrentIcon(newIcon);
  }
}

export function toggleMute() {
  const spk = wp.audio.default_speaker;
  console.log("[Volume] toggleMute called, speaker:", !!spk);
  if (spk) {
    const currentMute = !!spk.mute;
    const newMute = !currentMute;
    console.log("[Volume] Toggling mute from", currentMute, "to", newMute);
    
    // Update local state immediately for UI responsiveness
    console.log("[Volume] Setting currentMuted to:", newMute, "before hardware call");
    setCurrentMuted(newMute);
    
    // Force icon update immediately
    const newIcon = getVolumeIcon(currentVolume.get(), newMute);
    console.log("[Volume] Forcing icon update to:", newIcon);
    setCurrentIcon(newIcon);
    
    // Try the mute operation
    try {
      spk.set_mute(newMute);
      console.log("[Volume] set_mute() called successfully");
    } catch (error) {
      console.log("[Volume] Error setting mute:", error);
      // Revert local state on error
      setCurrentMuted(currentMute);
    }
  } else {
    console.log("[Volume] No speaker found for mute toggle");
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