import { With } from "ags";
import { Button } from "../../../lib/components";
import { weather, openWeatherApp } from "../service";
import { Gtk } from "ags/gtk4";

export function Weather() {
  return (
    <Button onClicked={openWeatherApp}>
      <With value={weather}>
        {(data) => (
          <box spacing={2} vexpand={false} valign={Gtk.Align.CENTER}>
            <label label={data?.icon || ""} />
            <label label={data ? `${data.feelsLike}°C` : "--°C"} />
          </box>
        )}
      </With>
    </Button>
  );
}
