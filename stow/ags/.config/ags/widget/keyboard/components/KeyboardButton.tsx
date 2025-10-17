import { Button } from "../../../lib/components";
import { keyboardLayout, switchKeyboardLayout } from "../service";

export function KeyboardButton({ class: cls }: { class?: string }) {
  return (
    <Button class={`keyboard-button ${cls ?? ""}`} onClicked={switchKeyboardLayout}>
      <label label={keyboardLayout((layout) => layout)} />
    </Button>
  );
}
