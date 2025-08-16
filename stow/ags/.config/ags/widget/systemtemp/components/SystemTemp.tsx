import { With } from "ags";
import { systemTemps } from "../service";
import Gio from "gi://Gio";
import { Gtk } from "ags/gtk4";

function getIcon(status: string) {
  const icon = {
    normal: "temperature-normal-symbolic",
    warm: "temperature-warm-symbolic",
    hot: "temperature-hot-symbolic",
  };
  return icon[status as keyof typeof icon];
}

export function SystemTemp({ class: cls }: { class?: string }) {
  return (
    <box class={`system-temp ${cls ?? ""}`}>
      <With value={systemTemps}>
        {({ cpu, gpu, avg, status }) => (
          <box
            class={`system-temps ${status}`}
            widthRequest={50}
            homogeneous={true}
          >
            <box halign={Gtk.Align.CENTER} spacing={2}>
              <image
                gicon={Gio.icon_new_for_string(getIcon(status))}
                pixelSize={12}
              />
              <label label={`${avg}°C`} />
            </box>
          </box>
        )}
      </With>
    </box>
  );
}
