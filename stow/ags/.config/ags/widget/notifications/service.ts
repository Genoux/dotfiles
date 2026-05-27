import { startUsbNotifications } from "../../services/usb";

export function startNotificationWatchers(): void {
  startUsbNotifications();
}
