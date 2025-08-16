import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import { With } from "ags";
import { lastPopup, popupVisible, dismissNotification, invokeDefault } from "../service";
import { getNotificationIcon, getNotificationAppName, formatRelativeTime } from "../utils";

export function NotificationPopup() {
  return (
    <window
      name="notification-popup"
      class="NotificationPopup"
      application={app}
      anchor={Astal.WindowAnchor.BOTTOM | Astal.WindowAnchor.RIGHT}
      visible={popupVisible}
    >
      <With value={lastPopup}>
        {(n: any) => (
          <box class="notification">
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
      </With>
    </window>
  );
}

