import { For } from "ags";
import { trayItems } from "../service";
import Tray from "gi://AstalTray";
import { Button } from "../../../lib/components";
import { hypr } from "../../../lib/hyprland";

function TrayItemComponent({ item }: { item: Tray.TrayItem }): JSX.Element {
  if (!item) return <box />;

  return (
    <Button
      class="tray-button"
      tooltipMarkup={item.tooltipMarkup}
      onClicked={() => {
        // Try to focus window using Hyprland for better compatibility
        if (hypr && item.id) {
          try {
            const windowClass = item.id.replace(/-client$/, "");
            hypr.dispatch("focuswindow", `class:${windowClass}`);
            return;
          } catch {
            // Fall through to standard activate
          }
        }

        // Fallback to standard tray activate
        try {
          item.activate(0, 0);
        } catch (e) {
          console.error(`Tray activate failed for ${item.id}:`, e);
        }
      }}
    >
      {item.gicon ? (
        <image gicon={item.gicon} pixelSize={12} />
      ) : (
        <label label={item.title?.[0] || "?"} />
      )}
    </Button>
  );
}

export function SystemTray({ class: cls }: { class?: string }) {
  return (
    <box
      class={`system-tray ${cls ?? ""}`}
      spacing={2}
      visible={trayItems((items) => items.length > 0)}
    >
      <For each={trayItems}>{(item: Tray.TrayItem) => <TrayItemComponent item={item} />}</For>
    </box>
  );
}
