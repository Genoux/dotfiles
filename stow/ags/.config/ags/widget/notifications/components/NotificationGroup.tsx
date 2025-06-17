import { bind, Variable } from "astal";
import { Gtk } from "astal/gtk3";
import { GLib } from "astal";
import Notification from "./Notification";
import { isGroupExpanded, setGroupExpanded } from "../Service";

interface NotificationGroupProps {
  appName: string;
  notifications: any[];
  isInCenter?: boolean;
}

export default function NotificationGroup({ 
  appName, 
  notifications, 
  isInCenter = false 
}: NotificationGroupProps) {
  // Use persistent state that survives component re-renders
  const isExpanded = Variable(isGroupExpanded(appName));
  const notificationCount = notifications.length;
  const latestNotification = notifications[0]; // Most recent notification
  const latestTime = GLib.DateTime.new_from_unix_local(latestNotification.time).format("%H:%M") || "";

  const toggleExpanded = () => {
    const newState = !isExpanded.get();
    isExpanded.set(newState);
    setGroupExpanded(appName, newState); // Persist the state
  };

  const dismissAllInGroup = () => {
    notifications.forEach((notif) => {
      try {
        notif.dismiss();
      } catch (error) {
        console.error("Failed to dismiss notification:", error);
      }
    });
  };

  return (
    <box className="notification-group" vertical spacing={4}>
      {/* Group Header - Custom styling without notification borders */}
      <eventbox
        className="notification-group-header"
        onButtonPressEvent={(_, event) => {
          if ((event as any).button === 1) {
            // Left click to expand/collapse
            toggleExpanded();
          }
        }}
      >
        <box className="notification-group-header-content" spacing={4}>
          <icon className="app-icon" icon={latestNotification.app_icon} />

          <label
            className="app-name"
            label={`${appName} (${notificationCount})`}
            hexpand
            halign={Gtk.Align.START}
          />

          <label className="timestamp" label={latestTime} />

          <box className="action-buttons">
            {bind(isExpanded).as(expanded => (
              <button
                className="close-btn"
                onClicked={toggleExpanded}
              >
                <icon icon={expanded ? "pan-up-symbolic" : "pan-down-symbolic"} />
              </button>
            ))}
            
            <button
              className="close-btn"
              onClicked={dismissAllInGroup}
            >
              <icon icon="window-close-symbolic" />
            </button>
          </box>
        </box>
      </eventbox>

      {/* Expanded notifications list */}
      {bind(isExpanded).as(expanded => (
        <box className="notification-group-expanded" spacing={4} vertical visible={expanded}>
          {notifications.map((notification, index) => (
            <box className="grouped-notification-wrapper">
              <Notification 
                notification={notification} 
                isInCenter={isInCenter}
              />
            </box>
          ))}
        </box>
      ))}
    </box>
  );
} 