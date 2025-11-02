import Bluetooth from "gi://AstalBluetooth";
import GLib from "gi://GLib";
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
    const cmd = `${GLib.get_home_dir()}/.local/bin/launch-bluetui`;
    console.log("[Bluetooth] Launching:", cmd);
    GLib.spawn_command_line_async(cmd);
  } catch (error) {
    console.error("Failed to launch bluetui:", error);
  }
}
