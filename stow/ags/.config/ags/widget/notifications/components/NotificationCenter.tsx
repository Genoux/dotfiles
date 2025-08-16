import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import { For, With } from "ags";
import { notifications, dismissNotification, centerVisible } from "../service";
import { getNotificationIcon, getNotificationAppName, formatRelativeTime } from "../utils";

export function NotificationCenterWindow() {
  return (
    <window
      name="notification-center-window"
      class="notification-center"
      application={app}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT | Astal.WindowAnchor.BOTTOM}
      exclusivity={Astal.Exclusivity.NORMAL}
      visible={centerVisible}
    >
      <box orientation={Gtk.Orientation.VERTICAL} spacing={0} widthRequest={500} vexpand={true}>
        <box class="notifications-header" spacing={8}>
          <label class="notification-title" label="Notifications" />
          <label class="notification-count" label={notifications((list: any[]) => `${list.length}`)} />
        </box>
        <scrolledwindow class="notification-list-scroll" vexpand={true} hexpand={true}>
          <box class="notification-list" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
            <For each={notifications as any}>
              {(n: any) => (
                <box class="notification clickable">
                  <box class="notification-container" spacing={8}>
                    <box class="notification-header" spacing={6}>
                      {(() => {
                        const icon = getNotificationIcon(n);
                        switch (icon.type) {
                          case "gicon":
                            return <image gicon={icon.value} pixelSize={16} class="app-icon" />;
                          case "file":
                            return <image file={icon.value} pixelSize={16} class="app-icon" />;
                          default:
                            return <image iconName={icon.value} pixelSize={16} class="app-icon" />;
                        }
                      })()}
                      <label class="app-name" label={getNotificationAppName(n)} />
                      <label class="timestamp" xalign={1.0} label={formatRelativeTime(n?.time)} />
                      <button halign={Gtk.Align.END} onClicked={() => dismissNotification(n)}>
                        <image iconName="window-close-symbolic" />
                      </button>
                    </box>
                    <box class="notification-body" spacing={8}>
                      <box class="text-content" spacing={4}>
                        <label class="summary" xalign={0.0} ellipsize={3} label={n?.summary || ""} />
                        <label class="body" xalign={0.0} ellipsize={3} label={n?.body || ""} />
                      </box>
                    </box>
                  </box>
                </box>
              )}
            </For>
            </box>
        </scrolledwindow>
      </box>
    </window>
  );
}

