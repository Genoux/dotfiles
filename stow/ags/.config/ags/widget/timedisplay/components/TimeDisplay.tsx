import { openCalendar, time } from "../service";
import { Button } from "../../../lib/components";

export function TimeDisplay({ class: cls }: { class?: string }) {
  return (
    <Button class={`time-display ${cls ?? ""}`} onClicked={openCalendar}>
      <label label={time((t) => t)} />
    </Button>
  );
}
