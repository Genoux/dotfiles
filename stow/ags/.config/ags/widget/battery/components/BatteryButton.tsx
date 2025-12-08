import { With } from "ags";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";
import { Gtk } from "ags/gtk4";
import { batteryStateAccessor, openBattop } from "../service";

export function BatteryButton() {
  return (
    <box visible={batteryStateAccessor((state) => state.available)}>
      <With value={batteryStateAccessor} >
        {({ icon, percentage }) => (
          <Button onClicked={openBattop}>
            <box spacing={2} vexpand={false} valign={Gtk.Align.CENTER}>
              <Icon icon={icon} size={12} />
              <label label={`${percentage}%`} />
            </box>
          </Button>
        )}
      </With></box>
  );
}

