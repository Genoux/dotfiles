import Wp from "gi://AstalWp";
import { createState } from "ags";
import { timeout } from "ags/time";
import { createOSDService } from "../../../services/osd";
import { getVolumeIcon } from "../../../services/volume";

const wp = Wp.get_default();
const osd = createOSDService(2000);

const [volumeState, setVolumeState] = createState({ volume: 0, muted: false });
const [volumeIcon, setVolumeIcon] = createState("audio-volume-medium-symbolic");
const [volumeLabel, setVolumeLabel] = createState("0%");

let speakerHandlerIds: number[] = [];
let lastVolume = 0;
let lastMuted = false;

function updateVolumeState() {
  const spk = wp.audio.default_speaker;
  if (!spk) return;

  const normalizedVol = Math.min(spk.volume, 1.0);
  const volumeChanged = normalizedVol !== lastVolume || spk.mute !== lastMuted;

  setVolumeState({ volume: normalizedVol, muted: spk.mute });
  setVolumeIcon(getVolumeIcon(spk.volume, spk.mute));

  const displayPercentage = spk.mute ? 0 : Math.min(Math.round(spk.volume * 100), 100);
  setVolumeLabel(spk.mute ? "Muted" : `${displayPercentage}%`);

  if (!osd.initializing && volumeChanged) {
    osd.show();
  }

  lastVolume = normalizedVol;
  lastMuted = spk.mute;
}

function setupSpeakerSignals() {
  const oldSpk = wp.audio.default_speaker;
  if (oldSpk && speakerHandlerIds.length > 0) {
    speakerHandlerIds.forEach((id) => oldSpk.disconnect(id));
    speakerHandlerIds = [];
  }

  const spk = wp.audio.default_speaker;
  if (spk) {
    speakerHandlerIds = [
      spk.connect("notify::volume", updateVolumeState),
      spk.connect("notify::mute", updateVolumeState),
    ];
  }
}

updateVolumeState();
setupSpeakerSignals();

wp.audio.connect("notify::default-speaker", () => {
  updateVolumeState();
  setupSpeakerSignals();
});

timeout(250, () => {
  osd.finishInitialization();
});

export { osd, volumeState, volumeIcon, volumeLabel };
