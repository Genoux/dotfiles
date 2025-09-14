import { For } from "ags";
import { Gtk } from "ags/gtk4";
import { workspaces, focusedWorkspace, workspaceClients } from "../service";

export function Workspaces({ class: cls }: { class?: string }) {
  return (
    <box class={`workspaces ${cls ?? ""}`} spacing={2}>
      <For each={workspaces}>
        {(ws: any) => (
          <button
            widthRequest={12}
            class={focusedWorkspace((f: any) =>
              f?.id === ws.id ? "workspace workspace--focused" : "workspace"
            )}
            onClicked={() => {
              try {
                ws.focus();
              } catch (e) {
                console.warn(`Failed to focus workspace ${ws.id}:`, e);
              }
            }}
          >
            <box
              heightRequest={6}
              widthRequest={2}
              halign={Gtk.Align.CENTER}
              valign={Gtk.Align.CENTER}
              class={focusedWorkspace((f: any) => {
                const isFocused = f?.id === ws.id;
                if (isFocused) {
                  return "workspace__indicator workspace__indicator--focused";
                }
                
                // For now, assume non-focused workspaces are occupied if they exist
                // This will give proper animations while we work on client detection
                return "workspace__indicator workspace__indicator--occupied";
              })}
            />
          </button>
        )}
      </For>
    </box>
  );
}
