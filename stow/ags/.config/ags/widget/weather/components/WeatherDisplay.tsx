import { With } from "ags";
import { Button } from "../../../lib/components";
import { weather, openWeatherApp } from "../service";

export function Weather({ class: cls }: { class?: string }) {
  return (
    <Button onClicked={openWeatherApp}>
      <With value={weather}>
        {({ icon, feelsLike }) => (
          <box class={cls} spacing={4}>
            <label label={icon} />
            <label label={`${feelsLike}°C`} />
          </box>
        )}
      </With>
    </Button>
  );
}
