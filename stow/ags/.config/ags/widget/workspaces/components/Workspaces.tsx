import { For } from "ags";
import { Gtk } from "ags/gtk4";
import { workspaces, focusedWorkspace } from "../service";

export function Workspaces({ class: cls }: { class?: string }) {
  return (
    <box class={`workspaces ${cls ?? ""}`} spacing={2}>
      <For each={workspaces}>
        {(ws) => (
          <button
            widthRequest={32}
            class={focusedWorkspace((f) =>
              f?.id === ws.id ? "workspace workspace--focused" : "workspace"
            )}
            onClicked={() => ws.focus()}
          >
            <box
              heightRequest={6}
              widthRequest={2}
              halign={Gtk.Align.CENTER}
              valign={Gtk.Align.CENTER}
              class={focusedWorkspace((f) =>
                f?.id === ws.id ? "workspace__indicator workspace__indicator--focused" : "workspace__indicator"
              )}
            />
          </button>
        )}
      </For>
    </box>
  );
}
