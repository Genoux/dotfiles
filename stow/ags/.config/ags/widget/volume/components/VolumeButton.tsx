import { currentIcon, openVolumeManager } from "../service";
import { Button } from "../../../lib/components";

export function VolumeButton({ class: cls = "" }: { class?: string }) {
  return (
    <box class={`${cls}`}>
      <Button canFocus={true} onClicked={openVolumeManager}>
        <image iconName={currentIcon((icon: string) => icon)} pixelSize={13} />
      </Button>
    </box>
  );
}
