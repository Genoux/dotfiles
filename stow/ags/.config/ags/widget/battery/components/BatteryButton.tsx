import { With } from "ags";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";
import { batteryStateAccessor, hasBatteryAvailable, openBattop } from "../service";

export function BatteryButton() {
  if (!hasBatteryAvailable) {
    return null;
  }

  return (
    <Button onClicked={openBattop}>
      <With value={batteryStateAccessor}>
        {({ icon, percentage }) => (
          <box spacing={2}>
            <Icon icon={icon} size={12} />
            <label label={`${percentage}%`} />
          </box>
        )}
      </With>
    </Button>
  );
}

