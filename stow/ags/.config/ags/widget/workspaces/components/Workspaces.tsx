import { For } from "ags";
import { Gtk } from "ags/gtk4";
import Hyprland from "gi://AstalHyprland";
import { focusedWorkspace, workspaces } from "../service";
import { switchWorkspace } from "../../../services/hyprland";
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
              onClicked={() => void switchWorkspace(wsId)}
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
