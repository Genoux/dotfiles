import { For } from "ags";
import { Gtk } from "ags/gtk4";
import { barsAccessor } from "../service";

const idxs = barsAccessor((b) => b.map((_, i) => i));

export function CavaVisualizer() {
  return (
    <box class='cava-island' spacing={2}>
      <For each={idxs} id={(i) => i}>
        {(i) => {
          const h = barsAccessor((b) => b[i]);
          const innerH = h((v) => v) as unknown as number;
          return (
            <box css="background: transparent;">
              <box
                class="cava-bar"
                widthRequest={3}
                heightRequest={innerH}
                valign={Gtk.Align.CENTER}
              />
            </box>
          );
        }}
      </For>
    </box>
  );
}
