import { 
  currentVolume, 
  currentIcon,
  currentMuted,
  setVolumeLevel,
  toggleMute,
  speaker,
  audioService,
  speakerVolume,
  speakerMuted
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
          console.log("[VolumePanel] Mute button clicked, current state:", currentMuted.get());
          toggleMute();
        }}
      >
        <image
          iconName={currentIcon((icon: string) => {
            console.log("[VolumePanel] Icon updated to:", icon);
            return icon;
          })}
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
        value={currentVolume((vol: number) => {
          console.log("[VolumeSlider] Reactive value:", vol);
          return clampVolume(vol);
        })}
        onChangeValue={(slider) => {
          const value = slider.value;
          console.log("[VolumeSlider] User changed value to:", value);
          setVolumeLevel(clampVolume(value));
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