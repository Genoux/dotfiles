import { With } from "ags";
import { weather } from "../Service";
import { Gtk } from "ags/gtk4";

export function Weather({ class: cls }: { class?: string }) {
  return (
    <box>
      <button>
    <With value={weather}>
      {(value) => {
        const { icon, feelsLike, location } = value as {
          icon: string;
          feelsLike: number;
          location: string;
        };
        return (
          <box
            class={`weather-widget ${cls ?? ""}`}
            widthRequest={64}
            homogeneous={true}
          >
            <box halign={Gtk.Align.CENTER} spacing={4}>
              <label label={icon} />
              <label label={`${feelsLike}°C`} />
            </box>
          </box>
        );
      }}
      </With>
      </button>
    </box>
  );
}
