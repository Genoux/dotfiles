import Wp from "gi://AstalWp";
import { createState } from "ags";
import GLib from "gi://GLib";

const wp = Wp.get_default();

// Track last icon, volume, and mute state for hysteresis to prevent flickering
let lastIcon: string | null = null;
let lastVolumeForIcon = -1;
let lastMutedState: boolean | null = null;

/**
 * Get volume icon with smooth transitions and hysteresis to prevent flickering
 * @param volume - Volume value (0.0 to 2.0, where 1.0 = 100%)
 * @param muted - Whether volume is muted
 * @returns Icon name string
 */
export function getVolumeIcon(volume: number, muted: boolean): string {
  // Track mute state changes - always update icon when mute state changes
  const muteStateChanged = lastMutedState !== null && lastMutedState !== muted;

  // Muted always shows muted icon (highest priority)
  if (muted) {
    lastIcon = "audio-volume-muted";
    lastVolumeForIcon = volume;
    lastMutedState = muted;
    return lastIcon;
  }

  // Normalize volume to 0-1.0 range for icon selection
  // WirePlumber uses 0-2.0 scale, but icons should treat 1.0+ as high
  const normalizedVol = Math.min(volume, 1.0);

  // Handle zero or near-zero volume
  if (normalizedVol <= 0.01) {
    lastIcon = "audio-volume-low";
    lastVolumeForIcon = volume;
    lastMutedState = muted;
    return lastIcon;
  }

  // Use clear, non-overlapping thresholds for smoother transitions
  // Thresholds: 0-33% = low, 33-66% = medium, 66-100% = high
  let newIcon: string;
  if (normalizedVol > 0.66) {
    newIcon = "audio-volume-high";
  } else if (normalizedVol > 0.33) {
    newIcon = "audio-volume-medium";
  } else {
    newIcon = "audio-volume-low";
  }

  // Add hysteresis: only change icon if volume has moved significantly
  // This prevents rapid icon changes when volume hovers around threshold values
  // BUT: always update if mute state changed (unmuting should immediately show correct icon)
  if (lastIcon === null || lastVolumeForIcon === -1 || muteStateChanged) {
    // First time, reset, or mute state changed - always update
    lastIcon = newIcon;
    lastVolumeForIcon = volume;
    lastMutedState = muted;
    return newIcon;
  }

  // If icon would change, require a meaningful volume change to prevent flickering
  if (newIcon !== lastIcon) {
    const volumeDelta = Math.abs(volume - lastVolumeForIcon);
    // Require at least 2% volume change to switch icons (prevents micro-adjustment flickering)
    if (volumeDelta >= 0.02) {
      lastIcon = newIcon;
      lastVolumeForIcon = volume;
      lastMutedState = muted;
      return newIcon;
    }
    // Keep previous icon if volume change is too small
    return lastIcon;
  }

  // Icon hasn't changed, but update tracking volume
  lastVolumeForIcon = volume;
  lastMutedState = muted;
  return newIcon;
}

function updateIcon(): string {
  try {
    const spk = wp!.audio.default_speaker;
    if (spk) {
      return getVolumeIcon(spk.volume, spk.mute);
    }
    return "audio-volume-high";
  } catch (error) {
    console.error("Volume update error:", error);
    return "audio-volume-high";
  }
}

// Use reactive state with signal-based updates instead of polling
export const [currentIcon, setCurrentIcon] = createState(updateIcon());

// Track speaker handlers to prevent duplicate connections
let speakerHandlerIds: number[] = [];

// Setup signal handlers for reactive updates
function setupSpeakerSignals() {
  // Disconnect old handlers
  const oldSpk = wp!.audio.default_speaker;
  if (oldSpk && speakerHandlerIds.length > 0) {
    speakerHandlerIds.forEach((id) => oldSpk.disconnect(id));
    speakerHandlerIds = [];
  }

  // Connect new handlers
  const spk = wp!.audio.default_speaker;
  if (spk) {
    speakerHandlerIds = [
      spk.connect("notify::volume", () => setCurrentIcon(updateIcon())),
      spk.connect("notify::mute", () => setCurrentIcon(updateIcon())),
    ];
  }
}

// Listen for default speaker property changes
wp!.audio.connect("notify::default-speaker", () => {
  setCurrentIcon(updateIcon());
  setupSpeakerSignals();
});

// Setup initial speaker signals
setupSpeakerSignals();

export function openVolumeManager() {
  try {
    GLib.spawn_command_line_async('launch-or-focus "wiremix" "wiremix" "multimedia-volume-control"');
  } catch (error) {
    console.error("Failed to launch wiremix:", error);
  }
}
