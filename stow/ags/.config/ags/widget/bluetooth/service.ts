import Bluetooth from "gi://AstalBluetooth";
import GLib from "gi://GLib";
import { Gtk } from "ags/gtk4";
import { createBinding, createState } from "ags";

// Safe Bluetooth initialization with error handling
let bluetooth: Bluetooth.Bluetooth | null = null;
let isBluetoothOn: any = null;

try {
  bluetooth = Bluetooth.get_default();
  isBluetoothOn = createBinding(bluetooth as any, "is-powered");
} catch (error) {
  console.warn("[Bluetooth] Failed to initialize Bluetooth service:", error);
  // Create a fallback state that always returns false
  isBluetoothOn = createState(false);
}

export { isBluetoothOn };

export function openBluetoothManager() {
  if (!bluetooth) {
    console.warn("[Bluetooth] Bluetooth service not available");
    return;
  }
  
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-bluetui`);
  } catch (error) {
    console.error("Failed to launch bluetui:", error);
  }
}

export function getConnectedDevices(): string[] {
  if (!bluetooth) return [];
  
  try {
    const devices = bluetooth.get_devices();
    
    return devices
      .filter((device: any) => device.connected === true && device.paired === true)
      .map((device: any) => device.name || device.address || "Unknown Device");
  } catch (error) {
    console.error("[Bluetooth] Failed to get connected devices:", error);
    return [];
  }
}

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
