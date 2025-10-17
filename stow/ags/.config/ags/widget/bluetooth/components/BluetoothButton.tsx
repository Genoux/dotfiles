import { isBluetoothOn, openBluetoothManager } from "../service";
import { Button } from "../../../lib/components";

export function BluetoothButton({ class: cls = "" }: { class?: string }) {
  return (
    <box class={`${cls}`}>
      <Button onClicked={openBluetoothManager}>
        <image
          iconName={isBluetoothOn((on) =>
            on ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
          )}
          pixelSize={12}
        />
      </Button>
    </box>
  );
}
