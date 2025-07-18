import { GLib } from "astal";
import { Gtk } from "astal/gtk3";
import { dismissPopupNotification } from "./NotificationPopup";
import { getNotificationIcon, getNotificationAppName } from "../utils";

// Simple notification component following original NotificationItem structure
export default function Notification({
  notification,
  isInCenter = false,
}: {
  notification: any;
  isInCenter?: boolean;
}) {
  const time = GLib.DateTime.new_from_unix_local(notification.time).format("%H:%M") || "";
  const { useGIcon, iconValue } = getNotificationIcon(notification);

  const actions = notification.get_actions?.() || [];
  return (
    <eventbox
      className="notification"
      onButtonPressEvent={(_, event) => {
        if ((event as any).button === 1) {
          const defaultAction = actions.find(
            (action: any) =>
              action.id === "default" ||
              action.id === "activate" ||
              actions.length === 1
          );

          if (defaultAction) {
            notification.invoke(defaultAction.id);
          }
        }
      }}
    >
      <box className="notification-container" vertical>
        {/* Notification Header */}
        <box className="notification-header" spacing={4}>
          {useGIcon ? (
            <icon className="app-icon" gicon={iconValue} />
          ) : (
            <icon className="app-icon" icon={iconValue} />
          )}
          <label
            className="app-name"
            label={getNotificationAppName(notification)}
            hexpand
            halign={Gtk.Align.START}
          />

          <label className="timestamp" label={time} />

          <box className="action-buttons">
            <button
              className="close-btn"
              onClicked={() => {
                if (isInCenter) {
                  // In notification center: clear/dismiss permanently
                  notification.dismiss();
                } else {
                  // Floating notification: just hide from popup (keep in center)
                  dismissPopupNotification(notification.id);
                }
              }}
            >
              <icon icon="window-close-symbolic" />
            </button>
          </box>
        </box>

        {/* Notification Content */}
        <box className="notification-body" spacing={8}>
          {notification.image && (
            <box
              className="notification-image"
              css={`
                background-image: url("${notification.image}");
              `}
            />
          )}

          <box className="text-content" vertical spacing={0}>
            {notification.summary && (
              <label
                className="summary"
                label={notification.summary}
                halign={Gtk.Align.START}
                wrap
                ellipsize={3}
              />
            )}

            {notification.body && (
              <label
                className="body"
                label={(notification.body || "").replace(/(\r\n|\n|\r)/gm, " ")}
                halign={Gtk.Align.START}
                wrap
                ellipsize={3}
              />
            )}
          </box>
        </box>

        {/* Notification Actions */}
        {actions && actions.length > 0 && (
          <box className="notification-actions" spacing={4}>
            {actions.map((action: any, i: number) => (
              <button
                className="notification-action-button"
                onClicked={() => {
                  try {
                    const result = notification.invoke(action.id);

                    // Try to focus the app window after action
                    setTimeout(() => {
                      try {
                        const appName = notification.app_name || "";
                        if (appName) {
                          GLib.spawn_command_line_async(`hyprctl dispatch focuswindow class:${appName}`);
                        }
                      } catch (focusError) {
                        console.error("Could not focus window:", focusError);
                      }
                    }, 200);


                    // Dismiss the notification after successful action
                    setTimeout(() => {
                      try {
                        if (isInCenter) {
                          notification.dismiss();
                        } else {
                          notification.dismiss();
                        }
                      } catch (dismissError) {
                        console.error(
                          "Could not dismiss notification:",
                          dismissError
                        );
                      }
                    }, 500);
                  } catch (error) {
                    console.error("Error invoking action:", error);
                  }
                }}
              >
                <label label={action.label || 'View'} />
              </button>
            ))}
          </box>
        )}
      </box>
    </eventbox>
  );
}
