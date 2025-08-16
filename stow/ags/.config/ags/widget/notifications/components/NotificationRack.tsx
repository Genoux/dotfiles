import app from "ags/gtk4/app";
import { Astal, Gtk } from "ags/gtk4";
import { For } from "ags";
import { rackNotifications, dismissNotification, invokeDefault } from "../service";
import { getNotificationIcon, getNotificationAppName, formatRelativeTime } from "../utils";

export function NotificationRack() {
  return (
    <window
      name="notification-rack"
      class="notification-rack"
      application={app}
      anchor={Astal.WindowAnchor.TOP | Astal.WindowAnchor.RIGHT}
      visible={true}
      layer={Astal.Layer.OVERLAY}
      marginTop={10}
      marginRight={10}
    >
      <box class="rack-container" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
        {/* Always visible debug element */}
        <box class="debug-notification" visible={true}>
          <label label="🔔 Notification Rack Active" />
        </box>
        
        {/* Dynamic notifications */}
        <For each={rackNotifications as any}>
          {(n: any) => (
            <box class="notification rack-item">
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
                  <button 
                    class="close-btn"
                    halign={Gtk.Align.END} 
                    onClicked={() => dismissNotification(n)}
                  >
                    <image iconName="window-close-symbolic" pixelSize={12} />
                  </button>
                </box>
                <box class="notification-body" spacing={4}>
                  <label class="summary" xalign={0.0} ellipsize={3} label={n?.summary || ""} />
                  <label class="body" xalign={0.0} ellipsize={3} label={n?.body || ""} />
                </box>
              </box>
            </box>
          )}
        </For>
      </box>
    </window>
  );
}