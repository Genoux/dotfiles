import { With } from "ags";
import { Button } from "../../../lib/components";
import { weather, openWeatherApp } from "../service";

export function Weather({ class: cls }: { class?: string }) {
  return (
    <Button onClicked={openWeatherApp}>
      <With value={weather}>
        {(data) => (
          <box class={cls} spacing={4}>
            <label label={data?.icon || ""} />
            <label label={data ? `${data.feelsLike}°C` : "--°C"} />
          </box>
        )}
      </With>
    </Button>
  );
}
