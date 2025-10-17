import { For } from "ags";
import { trayItems, handleTrayClick } from "../service";
import Tray from "gi://AstalTray";
import { Button } from "../../../lib/components";

function TrayItemComponent({ item }: { item: Tray.TrayItem }): JSX.Element {
  if (!item?.gicon) return <box />;

  return (
    <Button
      class="tray-button"
      tooltipMarkup={item.tooltipMarkup}
      onClicked={() => handleTrayClick(item)}
    >
      <image gicon={item.gicon} pixelSize={12} />
    </Button>
  );
}

export function SystemTray({ class: cls }: { class?: string }) {
  return (
    <box
      class={`system-tray ${cls ?? ""}`}
      spacing={4}
      visible={trayItems((items) => items.length > 0)}
    >
      <For each={trayItems}>{(item: Tray.TrayItem) => <TrayItemComponent item={item} />}</For>
    </box>
  );
}
