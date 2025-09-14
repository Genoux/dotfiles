import Bluetooth from "gi://AstalBluetooth";
import GLib from "gi://GLib";

export const bluetooth = Bluetooth.get_default();
import { createBinding } from "ags";

export const isBluetoothOn = createBinding(
  bluetooth as any,
  "is-powered"
);


export function openBluetoothManager() {
  try {
    const cmd = `${GLib.get_home_dir()}/.local/bin/launch-bluetui`;
    console.log("[Bluetooth] Launching:", cmd);
    GLib.spawn_command_line_async(cmd);
  } catch (error) {
    console.error("Failed to launch bluetui:", error);
  }
}