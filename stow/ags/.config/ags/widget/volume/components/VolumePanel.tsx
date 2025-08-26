import { 
  currentVolume, 
  currentIcon,
  currentMuted,
  setVolumeLevel,
  toggleMute
} from "../service";

function clampVolume(volume: number): number {
  return Math.min(Math.max(volume, 0), 1.0);
}

export function VolumePanel({ class: cls = "" }: { class?: string } = {}) {

  return (
    <box class={`volume-panel ${cls}`}>
      {/* Volume icon - click to mute/unmute */}
      <button 
        class={currentMuted((muted: boolean) => `volume-panel__mute-button ${muted ? 'muted' : ''}`)}
        canFocus={false}
        onClicked={() => {
          toggleMute();
        }}
      >
        <image
          iconName={currentIcon((icon: string) => icon)}
          pixelSize={20}
        />
      </button>

      {/* Volume slider - clean AGS component */}
      <slider
        class="volume-panel__slider"
        hexpand={true}
        min={0}
        max={1}
        step={0.01}
        value={currentVolume((vol: number) => clampVolume(vol))}
        onChangeValue={(slider) => {
          setVolumeLevel(clampVolume(slider.value));
        }}
      />

      {/* Volume value */}
      <label
        class="volume-panel__value"
        label={currentVolume((vol: number) => `${Math.round(clampVolume(vol) * 100)}%`)}
      />

      {/* Mute toggle handled by the icon button above */}
    </box>
  );
}