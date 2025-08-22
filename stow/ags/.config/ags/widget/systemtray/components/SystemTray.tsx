import { For } from "ags";
import { trayItems } from "../service";
import Tray from "gi://AstalTray";
import Hyprland from "gi://AstalHyprland";

function TrayItemComponent({ item }: { item: Tray.TrayItem }) {
  // Additional safety check - don't render if gicon is invalid
  if (!item || !item.gicon) {
    return null;
  }

  return (
    <button
      class="tray-button"
      onClicked={() => {
        try { item.activate(0, 0); } catch {}
        try { (item as any).secondaryActivate?.(0, 0); } catch {}
        try {
          const hypr = Hyprland.get_default();
          hypr?.dispatch?.("focuswindow", `class:${item.title}`);
        } catch {}
      }}
    >
      <image gicon={item.gicon} pixelSize={14} />
    </button>
  );
}

export function SystemTray({ class: cls }: { class?: string }) {
  return (
    <box
      class={`system-tray ${cls ?? ""}`}
      spacing={4}
      visible={trayItems((items) => items.length > 0)}
    >
      <For each={trayItems}>{(item) => <TrayItemComponent item={item} />}</For>
    </box>
  );
}
