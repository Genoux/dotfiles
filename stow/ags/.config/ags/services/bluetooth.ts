import Bluetooth from "gi://AstalBluetooth";
import { createBinding, createState } from "ags";
import { launchOrFocus } from "./hyprland";

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

  void launchOrFocus("bluetui", "bluetui", "bluetooth").catch((error) => {
    console.error("Failed to launch bluetui:", error);
  });
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
