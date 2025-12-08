import { openDotfilesMenu } from "../service";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";

export function SystemDotfilesButton() {
  return (
    <Button onClicked={openDotfilesMenu}>
      <Icon icon="input-keyboard" />
    </Button>
  );
}

