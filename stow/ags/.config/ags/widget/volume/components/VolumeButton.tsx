import { toggleVolumePanel } from "../service";
import Wp from "gi://AstalWp";
import { createBinding } from "ags";

function getVolumeIcon(volume: number, muted: boolean): string {
  if (muted) return "audio-volume-muted-symbolic";
  if (volume > 0.6) return "audio-volume-high-symbolic";
  if (volume > 0.3) return "audio-volume-medium-symbolic";
  if (volume > 0) return "audio-volume-low-symbolic";
  return "audio-volume-low-symbolic";
}

function clampVolume(volume: number): number {
  return Math.min(Math.max(volume, 0), 1.0);
}

export function VolumeButton({
  class: cls = "",
}: {
  class?: string;
}) {
  const audio = Wp.get_default();
  const speaker = audio?.get_default_speaker();
  
  if (!speaker) {
    return (
      <box class={`${cls}`}>
        <button onClicked={toggleVolumePanel}>
          <image
            iconName="audio-volume-muted-symbolic"
            pixelSize={16}
            css="transform: scale(0.8);"
          />
        </button>
      </box>
    );
  }

  const volume = createBinding(speaker, "volume");
  const muted = createBinding(speaker, "mute");

  return (
    <box class={`${cls}`}>
      <button onClicked={toggleVolumePanel}>
        <image
          iconName={muted((mute: boolean) => 
            getVolumeIcon(clampVolume(speaker.volume), mute)
          )}
          pixelSize={16}
          css="transform: scale(0.8);"
        />
      </button>
    </box>
  );
}