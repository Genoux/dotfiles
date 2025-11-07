import Wp from "gi://AstalWp";
import { createState } from "ags";
import { timeout } from "ags/time";
import { createOSDService } from "../../../services/osd";
import { getVolumeIcon } from "../../../services/volume";

const wp = Wp.get_default();

// Create generic OSD service
const osd = createOSDService(2000);

// Volume normalization - WirePlumber uses a 0-2.0 scale where:
// 0.0 = 0%, 1.0 = 100% (normal maximum), 2.0 = 200% (overamplification)
// For the bar display, we treat 1.0 as 100% filled (normal max)
// Values above 1.0 are also shown as 100% filled since they're overamplification
function normalizeVolume(rawVolume: number): number {
  // Normalize 0-1.0 range to 0-1.0 for display
  // Anything above 1.0 also shows as 1.0 (100% filled)
  return Math.min(rawVolume, 1.0);
}

// Volume-specific state management
const [volumeState, setVolumeState] = createState({ volume: 0, muted: false });
const [volumeIcon, setVolumeIcon] = createState("audio-volume-medium-symbolic");
const [volumeLabel, setVolumeLabel] = createState("0%");

// Track speaker handlers
let speakerHandlerIds: number[] = [];
let lastVolume = 0;
let lastMuted = false;

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
        const volumeChanged = normalizedVol !== lastVolume || spk.mute !== lastMuted;
        
        setVolumeState({ volume: normalizedVol, muted: spk.mute });
        updateDerivedState(normalizedVol, spk.mute, spk.volume);
        
        // Show OSD if volume actually changed
        // Note: WirePlumber may not fire signals when value is capped at max/min
        if (!osd.initializing && volumeChanged) {
          osd.show();
        }
        
        lastVolume = normalizedVol;
        lastMuted = spk.mute;
      }),
      spk.connect("notify::mute", () => {
        const normalizedVol = normalizeVolume(spk.volume);
        const volumeChanged = normalizedVol !== lastVolume || spk.mute !== lastMuted;
        
        setVolumeState({ volume: normalizedVol, muted: spk.mute });
        updateDerivedState(normalizedVol, spk.mute, spk.volume);
        
        // Show OSD if volume/mute actually changed
        if (!osd.initializing && volumeChanged) {
          osd.show();
        }
        
        lastVolume = normalizedVol;
        lastMuted = spk.mute;
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
  lastVolume = normalizedVol;
  lastMuted = spk.mute;
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
    osd.finishInitialization();
  });
});

function updateDerivedState(normalizedVol: number, muted: boolean, rawVol: number) {
  const validVol = isNaN(normalizedVol) ? 0 : normalizedVol;
  // Use the reusable getVolumeIcon from volume service
  // Pass raw volume (0-2.0 scale) for proper icon selection with hysteresis
  setVolumeIcon(getVolumeIcon(rawVol, muted));
  
  // Show percentage based on WirePlumber's scale where 1.0 = 100%
  // Cap at 100% for display even if volume goes higher (150%, 200%, etc.)
  const displayPercentage = muted ? 0 : Math.min(Math.round(rawVol * 100), 100);
  setVolumeLabel(muted ? "Muted" : `${displayPercentage}%`);
}

// Export state for components
export { osd, volumeState, volumeIcon, volumeLabel };

