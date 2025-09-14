import { currentIcon, openVolumeManager } from "../service";

export function VolumeButton({
  class: cls = "",
}: {
  class?: string;
}) {
  return (
    <box class={`${cls}`}>
      <button
        canFocus={true}
        onClicked={openVolumeManager}
      >
        <image
          iconName={currentIcon((icon: string) => icon)}
          pixelSize={13}
        />
      </button>
    </box>
  );
}