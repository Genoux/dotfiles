import { With } from "ags";
import { Gtk } from "ags/gtk4";
import GLib from "gi://GLib";
import { systemTemps, openSystemMonitor, type SystemTemps } from "../service";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";

const icons = {
  normal: "temperature-normal-symbolic",
  warm: "temperature-warm-symbolic",
  hot: "temperature-warm-symbolic",
};

function showTemperatureDetails(widget: Gtk.Widget) {
  try {
    const popover = new Gtk.Popover();
    popover.set_parent(widget);
    popover.set_autohide(true);
    popover.set_has_arrow(true);
    
    const content = new Gtk.Box({
      orientation: Gtk.Orientation.VERTICAL,
    });
    
    const cpuLabel = new Gtk.Label({ label: "" });
    const gpuLabel = new Gtk.Label({ label: "" });
    const avgLabel = new Gtk.Label({ label: "" });
    
    content.append(cpuLabel);
    content.append(gpuLabel);
    content.append(avgLabel);
    
    // Update labels reactively when temperature changes
    const updateLabels = () => {
      const temps = systemTemps.get() || { cpu: 0, gpu: 0, avg: 0, status: "normal" as const };
      cpuLabel.set_label(`CPU: ${temps.cpu}°C`);
      gpuLabel.set_label(`GPU: ${temps.gpu}°C`);
      avgLabel.set_label(`Avg: ${temps.avg}°C`);
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
          // Check if popover is still valid and has a parent before updating
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
    console.error("Failed to show temperature details:", error);
  }
}

export function SystemTemp() {
  return (
    <Button 
      onClicked={openSystemMonitor}
      $={(self: any) => {
        const rightClick = new Gtk.GestureClick();
        rightClick.set_button(3);
        rightClick.connect("released", () => showTemperatureDetails(self));
        self.add_controller(rightClick);
      }}
    >
      <With value={systemTemps}>
        {({ avg, status }) => (
          <box class={status}>
            <Icon icon={icons[status] || "temperature-normal-symbolic"} size={13} />
            <label label={`${avg}°C`} />
          </box>
        )}
      </With>
    </Button>
  );
}
