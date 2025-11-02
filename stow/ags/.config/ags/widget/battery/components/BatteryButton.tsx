import { With } from "ags";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";
import { batteryStateAccessor, openBattop } from "../service";

export function BatteryButton() {
  return (
    <With value={batteryStateAccessor}>
      {({ icon, percentage }) => (
        <Button onClicked={openBattop}>
          <box spacing={2}>
            <Icon icon={icon} size={12} />
            <label label={`${percentage}%`} />
          </box>
        </Button>
      )}
    </With>
  );
}

