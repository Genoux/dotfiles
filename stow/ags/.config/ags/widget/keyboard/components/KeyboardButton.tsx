import { Gtk } from "ags/gtk4";
import { keyboardLayout, switchKeyboardLayout } from "../service";

export function KeyboardButton({ class: cls }: { class?: string }) {
  return (
    <button
      class={`keyboard-button ${cls ?? ""}`}
      onClicked={switchKeyboardLayout}
    >
      <label label={keyboardLayout} />
    </button>
  );
}