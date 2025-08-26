import GLib from "gi://GLib";
import { isBluetoothOn } from "../service";

export function BluetoothButton({
  class: cls = "",
}: {
  class?: string;
}) {
  return (
    <box class={`${cls}`}>
      <button
        onClicked={() => GLib.spawn_command_line_async("launch-bluetui")}
      >
        <image
          iconName={isBluetoothOn((on) =>
            on ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
          )}
          pixelSize={16}
          css="transform: scale(0.8);" // adjust as needed
        />
      </button>
    </box>
  );
}
