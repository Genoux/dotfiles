import GLib from "gi://GLib";
import { isBluetoothOn, openBluetoothManager } from "../service";

export function BluetoothButton({
  class: cls = "",
}: {
  class?: string;
}) {
  return (
    <box class={`${cls}`}>
      <button
        onClicked={openBluetoothManager}
      >
        <image
          iconName={isBluetoothOn((on) =>
            on ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
          )}
          pixelSize={12}
        />
      </button>
    </box>
  );
}
