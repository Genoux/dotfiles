import GLib from "gi://GLib";
import { connected, checkConnection } from "../../services/network";

export { connected };

export const connectionIcon = connected((isOn: boolean) =>
  isOn ? checkConnection() : "network-offline-symbolic"
);

export function openInternetManager() {
  try {
    GLib.spawn_command_line_async(`${GLib.get_home_dir()}/.local/bin/launch-impala`);
  } catch (error) {
    console.error("Failed to launch launch-impala:", error);
  }
}
