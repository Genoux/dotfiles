import { openSystemInfo } from "../service";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";

export function SystemInfoButton() {
  return (
    <Button onClicked={openSystemInfo}>
      <Icon icon="system-run-symbolic" />
    </Button>
  );
}

