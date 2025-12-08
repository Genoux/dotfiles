import GLib from "gi://GLib";
import { Gtk } from "ags/gtk4";
import { connected, checkConnection, getNetworkSpeed } from "../../services/network";

export { connected };

export const connectionIcon = connected((isOn: boolean) =>
  isOn ? checkConnection() : "network-offline-symbolic"
);

export function openNetworkManager() {
  try {
    GLib.spawn_command_line_async(`launch-or-focus "impala" "impala" "impala"`);
  } catch (error) {
    console.error("Failed to launch launch-impala:", error);
  }
}

export function showNetworkSpeed(widget: any) {
  try {
    // Ensure widget is valid
    if (!widget || typeof widget.get_parent !== 'function') return;
    
    const popover = new Gtk.Popover();
    popover.set_parent(widget);
    popover.set_autohide(true);
    popover.set_has_arrow(true);
    
    const content = new Gtk.Box({
      orientation: Gtk.Orientation.VERTICAL,
      spacing: 4,
    });
    
    const downloadLabel = new Gtk.Label({ 
      label: "↓ 0 B/s",
      xalign: 0, // Align text to left
    });
    const uploadLabel = new Gtk.Label({ 
      label: "↑ 0 B/s",
      xalign: 0, // Align text to left
    });
    
    content.append(downloadLabel);
    content.append(uploadLabel);
    
    // Update labels with current speed
    const updateLabels = () => {
      const speed = getNetworkSpeed();
      downloadLabel.set_label(`↓ ${speed.downloadFormatted}`);
      uploadLabel.set_label(`↑ ${speed.uploadFormatted}`);
    };
    
    // Initial update
    updateLabels();
    
    // Poll for updates every 1 second while popover is open
    let updateInterval: number | null = null;
    let isActive = true;
    
    const cleanup = () => {
      isActive = false;
      if (updateInterval !== null) {
        GLib.source_remove(updateInterval);
        updateInterval = null;
      }
    };
    
    // Start polling timer
    updateInterval = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, 1, () => {
      if (isActive) {
        try {
          if (popover.get_parent() !== null) {
            updateLabels();
            return true; // Continue polling
          }
        } catch (error) {
          // Popover might be destroyed, stop polling
        }
      }
      cleanup();
      return false; // Stop polling
    });
    
    // Clean up when popover is closed
    popover.connect("closed", cleanup);
    
    // Also clean up when popover is unparented (autohide)
    popover.connect("notify::parent", () => {
      if (popover.get_parent() === null) {
        cleanup();
      }
    });
    
    popover.set_child(content);
    popover.popup();
  } catch (error) {
    console.error("Failed to show network speed:", error);
  }
}
