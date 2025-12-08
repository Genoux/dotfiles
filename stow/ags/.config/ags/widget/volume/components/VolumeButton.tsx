import { currentIcon, openVolumeManager } from "../service";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";

export function VolumeButton() {
  return (
    <Button onClicked={openVolumeManager}>
      <Icon icon={currentIcon((icon: string) => icon)} />
    </Button>
  );
}
