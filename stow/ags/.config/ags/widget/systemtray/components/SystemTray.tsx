import { For } from "ags";
import { trayItems } from "../service";
import Tray from "gi://AstalTray";
import Hyprland from "gi://AstalHyprland";

function TrayItemComponent({ item }: { item: Tray.TrayItem }): JSX.Element {
  // Additional safety check - don't render if gicon is invalid
  if (!item || !item.gicon) {
    return <box />; // Return empty box instead of null
  }

  return (
    <button
      class="tray-button"
      onClicked={() => {
        try { 
          // First try the standard tray activation
          item.activate(0, 0); 
        } catch {}
        
        try { 
          (item as any).secondaryActivate?.(0, 0); 
        } catch {}
        
        try {
          const hypr = Hyprland.get_default();
          
          // Get current clients to check if window exists
          const clients = hypr?.clients || [];
          const appName = item.title || item.id || "";
          
          // Find matching client
          const matchingClient = clients.find(client => 
            client.class?.toLowerCase().includes(appName.toLowerCase()) ||
            client.title?.toLowerCase().includes(appName.toLowerCase()) ||
            client.initialClass?.toLowerCase().includes(appName.toLowerCase())
          );
          
          if (matchingClient) {
            // If in special workspace, toggle it first
            if (matchingClient.workspace?.name?.includes("special")) {
              hypr?.dispatch?.("togglespecialworkspace", matchingClient.workspace.name.split(":")[1] || "special");
            }
            // Focus the specific window by address
            hypr?.dispatch?.("focuswindow", `address:0x${matchingClient.address}`);
          }
        } catch {}
      }}
    >
      <image gicon={item.gicon} pixelSize={12} />
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
      <For each={trayItems}>{(item: Tray.TrayItem) => <TrayItemComponent item={item} />}</For>
    </box>
  );
}
