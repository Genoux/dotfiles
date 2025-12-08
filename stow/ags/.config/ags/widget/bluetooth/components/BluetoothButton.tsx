import { Gtk } from "ags/gtk4";
import { isBluetoothOn, openBluetoothManager, showConnectedDevices } from "../service";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";

export function BluetoothButton() {
  if (!isBluetoothOn) {
    return <box />;
  }

  return (
    <Button 
      onClicked={openBluetoothManager}
      $={(self: any) => {
        const rightClick = new Gtk.GestureClick();
        rightClick.set_button(3);
        rightClick.connect("released", (_gesture: any, _n: number, _x: number, _y: number) => {
          showConnectedDevices(self);
        });
        self.add_controller(rightClick);
      }}
    >
      <Icon
        icon={isBluetoothOn((on: boolean) =>
          on ? "bluetooth-active-symbolic" : "bluetooth-disabled-symbolic"
        )}
      />
    </Button>
  );
}
