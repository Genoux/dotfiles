import { toggleVolumePanel, currentIcon, toggleMute } from "../service";

export function VolumeButton({
  class: cls = "",
}: {
  class?: string;
}) {
  return (
    <box class={`${cls}`}>
      <button 
        onClicked={toggleMute}
      >
        <image
          iconName={currentIcon((icon: string) => icon)}
          pixelSize={16}
        />
      </button>
    </box>
  );
}