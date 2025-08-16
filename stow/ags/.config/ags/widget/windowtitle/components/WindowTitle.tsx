import { With } from "ags";
import { client } from "../service";

export function WindowTitle({ class: cls = "" }: { class?: string }) {
  return (
    <With value={client}>
      {(c) => {
        const title = c?.get_title?.();
        const clsname = c?.get_class?.();

        return (
          <box class={`${cls}`} spacing={6} visible={!!c}>
            <image iconName={clsname} pixelSize={18} />
            <label label={title} xalign={0.0} maxWidthChars={40} ellipsize={3} marginEnd={3}/>
          </box>
        );
      }}
    </With>
  );
}
