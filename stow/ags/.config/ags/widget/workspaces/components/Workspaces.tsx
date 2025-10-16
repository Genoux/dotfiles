import { For } from "ags";
import { Gtk } from "ags/gtk4";
import Hyprland from "gi://AstalHyprland";
import { focusedWorkspace, workspaces, hypr } from "../service";

export function Workspaces({ class: cls }: { class?: string }) {
  return (
    <box class={`workspaces ${cls ?? ""}`} spacing={2}>
      <For each={workspaces}>
        {(ws: Hyprland.Workspace) => {
          const wsId = Number(ws.id);
          const hasClients = hypr ? hypr.get_clients().some((c: any) => Number(c.workspace?.id) === wsId) : false;

          return (
            // biome-ignore lint/a11y/useButtonType: GTK buttons don't support type prop
            <button
              class={focusedWorkspace((f: Hyprland.Workspace) =>
                Number(f?.id) === wsId ? "workspace workspace--focused" : "workspace"
              )}
              onClicked={() => {
                try {
                  ws.focus();
                } catch (e) {
                  console.warn(`Failed to focus workspace ${wsId}:`, e);
                }
              }}
            >
              <box
                halign={Gtk.Align.CENTER}
                valign={Gtk.Align.CENTER}
                class={focusedWorkspace((f: Hyprland.Workspace) => {
                  const isFocused = Number(f?.id) === wsId;
                  if (isFocused && hasClients) {
                    return "workspace__indicator workspace__indicator--focused";
                  }
                  return isFocused ? "workspace__number workspace__number--focused" : "workspace__number";
                })}
              >
                <box visible={focusedWorkspace((f: Hyprland.Workspace) => Number(f?.id) !== wsId || !hasClients)}>
                  <label label={String(wsId)} />
                </box>
              </box>
            </button>
          );
        }}
      </For>
    </box>
  );
}
