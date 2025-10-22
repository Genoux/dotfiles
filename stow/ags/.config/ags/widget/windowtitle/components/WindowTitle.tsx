import { focusedClient } from "../service";
import { truncateText, getAppIcon } from "../../../utils";

export function WindowTitle({ class: cls = "" }: { class?: string }) {
  if (!focusedClient) {
    return <box class={cls} />;
  }

  return (
    <box class={cls} spacing={6} visible={focusedClient((c) => !!c)}>
      <image
        iconName={focusedClient((c) => getAppIcon(c?.get_class() || ""))}
        pixelSize={18}
        visible={focusedClient((c) => !!c?.get_class())}
      />
      <label
        label={focusedClient((c) => {
          const title = c?.get_title() || "";
          return truncateText(title.trim(), 54);
        })}
      />
    </box>
  );
}
