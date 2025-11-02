import { Button } from "../../../lib/components";
import { keyboardLayout, switchKeyboardLayout } from "../service";

export function KeyboardButton() {
  return (
    <Button onClicked={switchKeyboardLayout}>
      <label label={keyboardLayout((layout) => layout)} />
    </Button>
  );
}
