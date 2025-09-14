import { Gtk } from "ags/gtk4";
import { openCalendar, time } from "../Service";

export function TimeDisplay({ class: cls }: { class?: string }) {
  return (
    <box hexpand={true} vexpand={true} class={`time-display ${cls ?? ""}`}>
      <button halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER} onClicked={openCalendar}>
        <box orientation={Gtk.Orientation.HORIZONTAL} spacing={6}>
          <label label={time((time) => time)} />
        </box>
      </button>
    </box>
  );
}
