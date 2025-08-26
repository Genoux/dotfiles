import { toggleVolumePanel, currentIcon } from "../service";

export function VolumeButton({
  class: cls = "",
}: {
  class?: string;
}) {
  return (
    <box class={`${cls}`}>
      <button 
        onClicked={toggleVolumePanel}
        canFocus={false}
      >
        <image
          iconName={currentIcon((icon: string) => icon)}
          pixelSize={16}
        />
      </button>
    </box>
  );
}