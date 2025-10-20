import { For } from "ags";
import { Gtk } from "ags/gtk4";
import { execAsync } from "ags/process";
import Hyprland from "gi://AstalHyprland";
import { focusedWorkspace, workspaces } from "../service";
import { Button } from "../../../lib/components";

export function Workspaces({ class: cls }: { class?: string }) {
  return (
    <box class={`workspaces ${cls ?? ""}`} spacing={2}>
      <For each={workspaces}>
        {(ws: Hyprland.Workspace) => {
          const wsId = ws.id;
          // Single binding per workspace to check if focused
          const isFocused = focusedWorkspace((f) => f?.id === wsId);

          return (
            <Button
              class={isFocused((focused) =>
                focused ? "workspace workspace--focused" : "workspace"
              )}
              onClicked={() =>
                execAsync(["system-workspace-switch", String(wsId)])
              }
            >
              <box
                halign={Gtk.Align.CENTER}
                valign={Gtk.Align.CENTER}
                class={isFocused((focused) =>
                  focused
                    ? "workspace__indicator workspace__indicator--focused"
                    : "workspace__number"
                )}
              >
                <box visible={isFocused((focused) => !focused)}>
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
