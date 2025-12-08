import { Button } from "../../../lib/components";
import { keyboardLayout, switchKeyboardLayout } from "../service";

export function KeyboardButton() {
  return (
    <box class='keyboard'>
      <Button class='' onClicked={switchKeyboardLayout}>
        <label label={keyboardLayout((layout) => layout)} />
      </Button>
    </box>
  );
}
