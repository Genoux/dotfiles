import { bind } from "astal"
import { Gtk } from "astal/gtk3"
import Notifd from "gi://AstalNotifd"
import { getCountableNotificationCount, notificationCenterVisible, toggleNotificationCenter } from "../Service"
import { Variable } from "astal"

const notifications = Notifd.get_default()

export default function NotificationButton() {
 
  return (
    <button
      className={bind(Variable.derive([
        bind(notifications, "notifications"), 
        notificationCenterVisible
      ], (notifs, centerVisible) => {
        const count = getCountableNotificationCount(notifs)
        const baseClass = `NotificationButton${count > 0 ? " has-notifications" : ""}`
        const visibleClass = centerVisible ? " active" : ""
        return baseClass + visibleClass
      }))}
      onClicked={
        () => {
          toggleNotificationCenter()
        }
      }
      halign={Gtk.Align.CENTER}
      valign={Gtk.Align.CENTER}
    >
      <box 
        spacing={1}
        halign={Gtk.Align.CENTER}
        valign={Gtk.Align.CENTER}
      >
        <icon
          className="notification-icon"
          icon={"notification"}
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
        />
        <box
          className="badge"
          halign={Gtk.Align.CENTER}
          valign={Gtk.Align.CENTER}
          visible={bind(notifications, "notifications").as(notifs => {
            const count = getCountableNotificationCount(notifs)
            return count > 0
          })}
        >
          <label label={bind(notifications, "notifications").as(notifs => {
            const count = getCountableNotificationCount(notifs)
            return `${count}`
          })} />
        </box>
      </box>
    </button>
  )
} 