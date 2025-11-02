import { openCalendar, time } from "../service";
import { Button } from "../../../lib/components";

export function TimeDisplay() {
  return (
    <Button onClicked={openCalendar}>
      <label label={time((t) => t)} />
    </Button>
  );
}
