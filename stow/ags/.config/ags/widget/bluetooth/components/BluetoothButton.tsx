import { isBluetoothOn, openBluetoothManager } from "../service";
import { Button } from "../../../lib/components";

export function BluetoothButton({ class: cls = "" }: { class?: string }) {
  // Only render if Bluetooth service is available
  if (!isBluetoothOn) {
    return <box class={`${cls}`} />;
  }

  return (
    <box class={`${cls}`}>
      <Button onClicked={openBluetoothManager}>
        <image
          iconName={isBluetoothOn((on: boolean) =>
            on ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
          )}
          pixelSize={13}
        />
      </Button>
    </box>
  );
}
