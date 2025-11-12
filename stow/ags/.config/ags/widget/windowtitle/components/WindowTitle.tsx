import { focusedClient, clientTitle, clientClass } from "../service";
import { truncateText, getAppIcon } from "../../../utils";
import { Gtk } from "ags/gtk4";
import Icon from "../../../components/Icon";

export function WindowTitle() {
  if (!focusedClient) {
    return <box />;
  }

  return (
    <box spacing={6} visible={focusedClient((c) => !!c)} vexpand={false} valign={Gtk.Align.CENTER} halign={Gtk.Align.CENTER}>
      <Icon
        icon={clientClass((cls) => getAppIcon(cls || ""))}
        size={18}
      />
      <label
        label={clientTitle((title) => truncateText(title.trim(), 54))}
      />
    </box>
  );
}
