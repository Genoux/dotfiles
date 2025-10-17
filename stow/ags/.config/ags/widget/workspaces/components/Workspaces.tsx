import { For } from "ags";
import { Gtk } from "ags/gtk4";
import Hyprland from "gi://AstalHyprland";
import { focusedWorkspace, workspaces } from "../service";
import { workspaceHasClients } from "../../../lib/hyprland";
import { Button } from "../../../lib/components";

export function Workspaces({ class: cls }: { class?: string }) {
  return (
    <box class={`workspaces ${cls ?? ""}`} spacing={2}>
      <For each={workspaces}>
        {(ws: Hyprland.Workspace) => {
          const wsId = ws.id;
          const hasClients = workspaceHasClients(wsId);

          return (
            <Button
              class={focusedWorkspace((f) =>
                f?.id === wsId ? "workspace workspace--focused" : "workspace"
              )}
              onClicked={() => ws.focus()}
            >
              <box
                halign={Gtk.Align.CENTER}
                valign={Gtk.Align.CENTER}
                class={focusedWorkspace((f) => {
                  const isFocused = f?.id === wsId;
                  return isFocused
                    ? "workspace__indicator workspace__indicator--focused"
                    : "workspace__number";
                })}
              >
                <box visible={focusedWorkspace((f) => f?.id !== wsId)}>
                  <label label={String(wsId)} />
                </box>
              </box>
            </Button>
          );
        }}
      </For>
    </box>
  );
}
