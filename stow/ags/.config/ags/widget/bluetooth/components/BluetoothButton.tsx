import { isBluetoothOn, openBluetoothManager } from "../service";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";

export function BluetoothButton() {
  if (!isBluetoothOn) {
    return <box />;
  }

  return (
    <Button onClicked={openBluetoothManager}>
      <Icon
        icon={isBluetoothOn((on: boolean) =>
          on ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
        )}
      />
    </Button>
  );
}
