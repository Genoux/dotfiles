import GLib from "gi://GLib";
import { Button } from "../../../lib/components";

export function NotificationPanelButton({ class: cls = "" }: { class?: string }) {
  return (
    <box class={`${cls}`}>
      <Button onClicked={() => GLib.spawn_command_line_async("swaync-client -t")}>
        <image iconName="notification-symbolic" pixelSize={11} />
      </Button>
    </box>
  );
}
