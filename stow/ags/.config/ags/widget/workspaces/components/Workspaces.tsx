import { For } from "ags";
import { Gtk } from "ags/gtk4";
import { execAsync } from "ags/process";
import Hyprland from "gi://AstalHyprland";
import { focusedWorkspace, workspaces } from "../service";
import { Button } from "../../../lib/components";

export function Workspaces() {
  return (
    <box spacing={2} class='workspace' >
      <For each={workspaces}>
        {(ws: Hyprland.Workspace) => {
          const wsId = ws.id;
          const isFocused = focusedWorkspace((f) => f?.id === wsId);

          return (
            <Button
              class={isFocused((focused) => (focused ? "focused" : ""))}
              onClicked={() =>
                execAsync(["system-workspace-switch", String(wsId)])
              }
            >
              <label
                label={isFocused((focused) => (focused ? "●" : String(wsId)))}
              />
            </Button>
          );
        }}
      </For>

    </box>
  );
}
