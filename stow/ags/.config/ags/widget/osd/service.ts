//TODO: Fix visibility glitch when volume is changed quickly after 2 sec (closing)

import Wp from "gi://AstalWp";
import { createState } from "ags";
import { timeout } from "ags/time";

const wp = Wp.get_default();

// OSD state management
const [isVisible, setIsVisible] = createState(false);
const [volumeState, setVolumeState] = createState({ volume: 0, muted: false });
const [volumeIcon, setVolumeIcon] = createState("audio-volume-medium-symbolic");
const [volumeLabel, setVolumeLabel] = createState("0%");

// Background brightness detection behind OSD (light/dark mode)
// Make it reactive to isVisible changes
// Track speaker handlers
let speakerHandlerIds: number[] = [];
let isInitializing = true;

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
      spk.connect("notify::volume", () => {
        setVolumeState({ volume: spk.volume, muted: spk.mute });
        updateDerivedState(spk.volume, spk.mute);
        if (!isInitializing) showOSD();
      }),
      spk.connect("notify::mute", () => {
        setVolumeState({ volume: spk.volume, muted: spk.mute });
        updateDerivedState(spk.volume, spk.mute);
        if (!isInitializing) showOSD();
      }),
    ];
  }
}

// Listen for default speaker changes
wp.audio.connect("notify::default-speaker", () => {
  const spk = wp.audio.default_speaker;
  if (spk) {
    setVolumeState({ volume: spk.volume, muted: spk.mute });
    updateDerivedState(spk.volume, spk.mute);
  }
  setupSpeakerSignals();
});

// Initialize
setupSpeakerSignals();
const spk = wp.audio.default_speaker;
if (spk) {
  setVolumeState({ volume: spk.volume, muted: spk.mute });
  updateDerivedState(spk.volume, spk.mute);
}

// Disable initialization flag after setup
timeout(100, () => {
  isInitializing = false;
});

// Track OSD hide timeout
let hideTimeoutId = 0;

export function showOSD() {
  setIsVisible(true);

  // Increment timeout ID to invalidate previous timeouts
  const currentTimeoutId = ++hideTimeoutId;

  // Set new timeout to hide OSD
  timeout(2000, () => {
    // Only hide if this is still the latest timeout
    if (currentTimeoutId === hideTimeoutId) {
      setIsVisible(false);
    }
  });
}

export function getVolumeIcon(vol: number, muted: boolean): string {
  if (muted) {
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

function updateDerivedState(vol: number, muted: boolean) {
  const validVol = isNaN(vol) ? 0 : vol;
  setVolumeIcon(getVolumeIcon(validVol, muted));
  setVolumeLabel(muted ? "Muted" : `${Math.round(validVol * 100)}%`);
}

// Export state for components
export { isVisible, volumeState, volumeIcon, volumeLabel };
