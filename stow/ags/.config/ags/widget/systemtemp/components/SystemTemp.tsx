import { With } from "ags";
import { Gtk } from "ags/gtk4";
import Gio from "gi://Gio";
import { systemTemps, openSystemMonitor } from "../service";
import { Button } from "../../../lib/components";

const icons = {
  normal: "temperature-normal-symbolic",
  warm: "temperature-warm-symbolic",
  hot: "temperature-hot-symbolic",
};

export function SystemTemp({ class: cls }: { class?: string }) {
  return (
    <Button class={`system-temp ${cls ?? ""}`} onClicked={openSystemMonitor}>
      <With value={systemTemps}>
        {({ avg, status }) => (
          <box class={`system-temps ${status}`} halign={Gtk.Align.CENTER} spacing={2}>
            <image gicon={Gio.icon_new_for_string(icons[status])} pixelSize={12} />
            <label label={`${avg}°C`} />
          </box>
        )}
      </With>
    </Button>
  );
}
