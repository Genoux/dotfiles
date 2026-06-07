import { Gtk } from "ags/gtk4";
import {
  getConnectedDevices,
  isBluetoothOn,
  openBluetoothManager,
} from "../../services/bluetooth";

export { isBluetoothOn, openBluetoothManager };

export function showConnectedDevices(widget: any) {
  try {
    if (!widget) return;

    const connectedDevices = getConnectedDevices();

    const popover = new Gtk.Popover();
    popover.set_parent(widget);
    popover.set_autohide(true);
    popover.set_has_arrow(true);

    const content = new Gtk.Box({
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 4,
    });

    if (connectedDevices.length === 0) {
      const noDeviceLabel = new Gtk.Label({
        label: "No devices connected",
        xalign: 0,
      });
      content.append(noDeviceLabel);
    } else {
      connectedDevices.forEach((deviceName) => {
        const deviceLabel = new Gtk.Label({
          label: deviceName,
          xalign: 0,
        });
        content.append(deviceLabel);
      });
    }

    popover.set_child(content);
    popover.popup();
  } catch (error) {
    console.error("Failed to show connected devices:", error);
  }
}
