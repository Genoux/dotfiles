import { For } from "ags";
import { Gtk } from "ags/gtk4";
import { barsAccessor, BAR_COUNT } from "../service";
import { toggleMediaPanel } from "../../mediaplayer/service";


const idxs = barsAccessor((b) => b.map((_, i) => i));

export function CavaVisualizer({ class: cls }: { class?: string }) {
  return (
   <button class={`cava-island ${cls ?? ""}`} onClicked={toggleMediaPanel}>
     <box class="cava-wrapper" spacing={2}>
        <For each={idxs} id={(i) => i}>
          {(i) => {
            const h = barsAccessor((b) => b[i]);
            const innerH = h((v) => v) as unknown as number;
            const offset = Math.floor(innerH / 2);
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
   </button>
  );
}
