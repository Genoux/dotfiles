import { Gtk } from "ags/gtk4";
import { time } from "../Service";

export function TimeDisplay({ class: cls }: { class?: string }) {
  return (
    <box class={`time-display ${cls ?? ""}`}>
      <menubutton halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
        <label label={time} />
        <popover>
          <Gtk.Calendar />
        </popover>
      </menubutton>
    </box>
  );
}
