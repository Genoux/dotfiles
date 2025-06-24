import { bind } from "astal";
import { Gtk } from "astal/gtk3";
import Notifd from "gi://AstalNotifd";
import Notification from "./Notification";
import NotificationGroup from "./NotificationGroup";
import { filterVisibleNotifications, processNotificationsForGrouping, NOTIFICATION_GROUP_THRESHOLD } from "../Service";

import { getCurrentWindowClose } from "../../utils/WindowHelper"

interface NotificationCenterProps {
  showCloseButton?: boolean;
}

export default function NotificationCenter({ showCloseButton = true }: NotificationCenterProps) {
  const notifd = Notifd.get_default();

  return (
    <box className={`notification-center ${showCloseButton ? 'floating' : ''}`} vertical spacing={8} vexpand hexpand>
      <box className="notifications-header" hexpand>
        <label
          label="Notifications"
          className="notification-title"
          halign={Gtk.Align.START}
        />
        <box>
        <box halign={Gtk.Align.END} hexpand>  
        <button
            className="clear-all-btn"
            onClicked={() => {
              // Clear all notifications
              const notifications = notifd.notifications;
              notifications.forEach((notif) => {
                try {
                  notif.dismiss();
                } catch (error) {
                  console.error("Failed to dismiss notification:", error);
                }
              });
            }}
          >
            <label label="Clear All" />
          </button>
          {showCloseButton && (
            <button
              hexpand
              className="close-btn"
              halign={Gtk.Align.END}
              onClicked={() => {
                const closeWindow = getCurrentWindowClose()
                if (closeWindow) {
                  closeWindow() // Properly closes window + cleans up click catcher
                }
              }}
            >
              <icon icon="close" />
            </button>
          )}
        </box>
        </box>
      </box>

      <scrollable
        className="notification-list"
        vexpand
        hscroll={Gtk.PolicyType.NEVER}
        vscroll={Gtk.PolicyType.AUTOMATIC}
        maxContentHeight={400}
      >
        <box vertical spacing={4} className="notification-list-content">
          {bind(notifd, "notifications").as((notifications) => {
            const visibleNotifications =
              filterVisibleNotifications(notifications);

            if (visibleNotifications.length === 0) {
              return (
                <box
                  className="no-notifications"
                  halign={Gtk.Align.CENTER}
                  valign={Gtk.Align.CENTER}
                  vexpand
                  hexpand
                >
                  <label
                    label="No notifications"
                    className="no-notifications-text"
                    halign={Gtk.Align.CENTER}
                    valign={Gtk.Align.CENTER}
                  />
                </box>
              );
            }

            // Process notifications for grouping (threshold: 3)
            const { groupedApps, ungroupedNotifications } = 
              processNotificationsForGrouping(visibleNotifications, NOTIFICATION_GROUP_THRESHOLD);

            const elements: any[] = [];

            // Add grouped notifications first
            Object.entries(groupedApps).forEach(([appName, appNotifications]) => {
              elements.push(
                <NotificationGroup
                  appName={appName}
                  notifications={appNotifications}
                  isInCenter={true}
                />
              );
            });

            // Add ungrouped notifications
            ungroupedNotifications.forEach((notification) => {
              elements.push(
                <Notification 
                  notification={notification} 
                  isInCenter={true} 
                />
              );
            });

            return elements;
          })}
        </box>
      </scrollable>
    </box>
  );
}

// Export a widget version for use in other components
export function NotificationCenterWidget() {
  return <NotificationCenter showCloseButton={false} />;
}
