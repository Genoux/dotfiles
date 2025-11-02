import { focusedClient, clientTitle, clientClass } from "../service";
import { truncateText, getAppIcon } from "../../../utils";
import Icon from "../../../components/Icon";

export function WindowTitle() {
  if (!focusedClient) {
    return <box />;
  }

  return (
    <box spacing={6} visible={focusedClient((c) => !!c)}>
      <Icon
        icon={clientClass((cls) => getAppIcon(cls || ""))}
        size={16}
      />
      <label
        label={clientTitle((title) => truncateText(title.trim(), 54))}
      />
    </box>
  );
}
