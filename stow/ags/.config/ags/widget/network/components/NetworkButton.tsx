import { Gtk } from "ags/gtk4";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";
import { connectionIcon, openNetworkManager, showNetworkSpeed } from "../service";

export function NetworkButton() {
  return (
    <Button
      onClicked={openNetworkManager}
      $={(self: any) => {
        const rightClick = new Gtk.GestureClick();
        rightClick.set_button(3);
        rightClick.connect("released", () => showNetworkSpeed(self));
        self.add_controller(rightClick);
      }}
    >
      <Icon icon={connectionIcon} />
    </Button>
  );
}
