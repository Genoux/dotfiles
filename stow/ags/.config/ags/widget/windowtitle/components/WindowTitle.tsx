import { focusedClient } from "../service";
import { truncateText, getAppIcon } from "../../../utils";
import Icon from "../../../components/Icon";

export function WindowTitle() {
  if (!focusedClient) {
    return <box />;
  }

  return (
    <box spacing={6} visible={focusedClient((c) => !!c)}>
      <Icon
        icon={focusedClient((c) => getAppIcon(c?.get_class() || ""))}
        size={16}
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
