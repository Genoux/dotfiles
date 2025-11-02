import { For } from "ags";
import { Gtk } from "ags/gtk4";
import Tray from "gi://AstalTray";
import { Button } from "../../../lib/components";
import {
  trayItems,
  registerIconTheme,
  handlePrimaryClick,
  handleSecondaryClick,
  handleMiddleClick,
} from "../service";

function TrayButton({ item }: { item: Tray.TrayItem }) {
  registerIconTheme(item);

  return (
    <Button
      tooltipText={item.title || item.tooltip_markup || item.id}
      onClicked={() => handlePrimaryClick(item)}
      $={(self: any) => {
        if (item.actionGroup) {
          self.insert_action_group("dbusmenu", item.actionGroup);
        }

        const rightClick = new Gtk.GestureClick();
        rightClick.set_button(3);
        rightClick.connect("released", () => handleSecondaryClick(item, self));
        self.add_controller(rightClick);

        const middleClick = new Gtk.GestureClick();
        middleClick.set_button(2);
        middleClick.connect("released", () => handleMiddleClick(item));
        self.add_controller(middleClick);
      }}
    >
      <image gicon={item.gicon} pixelSize={13} />
    </Button>
  );
}

export function SystemTray() {
  return (
    <box
      class='system-tray'
      visible={trayItems((list) => list.length > 0)}
    >
      <For each={trayItems}>
        {(item) => <TrayButton item={item} />}
      </For>
    </box>
  );
}