import Wp from "gi://AstalWp";
import { createState } from "ags";
import { timeout } from "ags/time";

const wp = Wp.get_default();

// Volume normalization - WirePlumber uses a 0-2.0 scale where:
// 0.0 = 0%, 1.0 = 100% (normal maximum), 2.0 = 200% (overamplification)
// For the bar display, we treat 1.0 as 100% filled (normal max)
// Values above 1.0 are also shown as 100% filled since they're overamplification
function normalizeVolume(rawVolume: number): number {
  // Normalize 0-1.0 range to 0-1.0 for display
  // Anything above 1.0 also shows as 1.0 (100% filled)
  return Math.min(rawVolume, 1.0);
}

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
        const normalizedVol = normalizeVolume(spk.volume);
        setVolumeState({ volume: normalizedVol, muted: spk.mute });
        updateDerivedState(normalizedVol, spk.mute, spk.volume);
        if (!isInitializing) showOSD();
      }),
      spk.connect("notify::mute", () => {
        const normalizedVol = normalizeVolume(spk.volume);
        setVolumeState({ volume: normalizedVol, muted: spk.mute });
        updateDerivedState(normalizedVol, spk.mute, spk.volume);
        if (!isInitializing) showOSD();
      }),
    ];
  }
}

// Listen for default speaker changes
wp.audio.connect("notify::default-speaker", () => {
  const spk = wp.audio.default_speaker;
  if (spk) {
    const normalizedVol = normalizeVolume(spk.volume);
    setVolumeState({ volume: normalizedVol, muted: spk.mute });
    updateDerivedState(normalizedVol, spk.mute, spk.volume);
  }
  setupSpeakerSignals();
});

// Initialize state first (without triggering signals)
const spk = wp.audio.default_speaker;
if (spk) {
  const normalizedVol = normalizeVolume(spk.volume);
  setVolumeState({ volume: normalizedVol, muted: spk.mute });
  updateDerivedState(normalizedVol, spk.mute, spk.volume);
}

// Connect signals after initial state is set
// This prevents signals from firing during initialization
timeout(50, () => {
  setupSpeakerSignals();
  
  // Disable initialization flag after signals are connected
  // Give extra time to ensure no signals fire during startup
  timeout(200, () => {
    isInitializing = false;
  });
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

function updateDerivedState(normalizedVol: number, muted: boolean, rawVol: number) {
  const validVol = isNaN(normalizedVol) ? 0 : normalizedVol;
  setVolumeIcon(getVolumeIcon(validVol, muted));
  
  // Show percentage based on WirePlumber's scale where 1.0 = 100%
  // Cap at 100% for display even if volume goes higher (150%, 200%, etc.)
  const displayPercentage = muted ? 0 : Math.min(Math.round(rawVol * 100), 100);
  setVolumeLabel(muted ? "Muted" : `${displayPercentage}%`);
}

// Export state for components
export { isVisible, volumeState, volumeIcon, volumeLabel };
