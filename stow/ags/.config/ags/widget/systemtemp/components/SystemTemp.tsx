import { With } from "ags";
import { Gtk } from "ags/gtk4";
import {
  systemTemps,
  openSystemMonitor,
  showTemperatureDetails,
  getTempIcon,
  formatTempLabel,
} from "../service";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";

export function SystemTemp() {
  return (
    <Button
      onClicked={openSystemMonitor}
      $={(self: any) => {
        const rightClick = new Gtk.GestureClick();
        rightClick.set_button(3);
        rightClick.connect("released", () => showTemperatureDetails(self));
        self.add_controller(rightClick);
      }}
    >
      <With value={systemTemps}>
        {(temps) => (
          <box class={temps.status} vexpand={false} valign={Gtk.Align.CENTER}>
            <Icon icon={getTempIcon(temps.status)} size={13} />
            <label label={formatTempLabel(temps)} />
          </box>
        )}
      </With>
    </Button>
  );
}
