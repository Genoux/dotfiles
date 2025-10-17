import { client } from "../service";
import { truncateText, getAppIcon } from "../../../utils";

export function WindowTitle({ class: cls = "" }: { class?: string }) {
  return (
    <box class={cls} spacing={6} visible={client((c) => !!c && !!c.title)}>
      <image iconName={client((c) => getAppIcon(c?.class || ""))} pixelSize={18} />
      <label
        label={client((c) => {
          const title = (c?.title || "").trim();
          return truncateText(title, 54);
        })}
        xalign={0.0}
        marginEnd={3}
      />
    </box>
  );
}
