import GLib from "gi://GLib";

export function NotificationPanelButton({
  class: cls = "",
}: {
  class?: string;
}) {
  return (
    <box class={`${cls}`}>
      <button
        onClicked={() => GLib.spawn_command_line_async("swaync-client -t")}
      >
        <image
          iconName="notification-symbolic"
          pixelSize={12}
        />
      </button>
    </box>
  );
}