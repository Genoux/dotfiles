import { For, With } from "ags";
import { trayItems } from "../service";
import Tray from "gi://AstalTray";

function TrayItemComponent({ item }: { item: Tray.TrayItem }) {
  return (
    <button onClicked={() => item.activate(0, 0)} class="tray-button">
      <image gicon={item.gicon} pixelSize={14} />
    </button>
  );
}

export function SystemTray({ class: cls }: { class?: string }) {
  return (
    <box
      class={`system-tray ${cls ?? ""}`}
      spacing={4}
      visible={trayItems((items) => items.length > 0)}
    >
      <For each={trayItems}>{(item) => <TrayItemComponent item={item} />}</For>
    </box>
  );
}
