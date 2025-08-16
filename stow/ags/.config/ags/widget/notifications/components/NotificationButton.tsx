import { For, With } from "ags";
import { Gtk } from "ags/gtk4";
import { notifications, toggleNotificationCenter } from "../service";
import { getNotificationIcon, getNotificationAppName } from "../utils";

export function NotificationButton({ class: cls = "" }: { class?: string }) {
  return (
    <box class={`${cls}`}>
      <button class={`NotificationButton`} onClicked={toggleNotificationCenter}>
        <box spacing={4} halign={Gtk.Align.CENTER} valign={Gtk.Align.CENTER}>
          <image
            class="icon"
            iconName="notification"
            pixelSize={12}
          />
          <With value={notifications as any}>
            {(list: any[] = []) =>
              list.length > 0 ? (
                <box class="badge">
                  <label label={`${list.length}`} />
                </box>
              ) : null
            }
          </With>
        </box>
      </button>
    </box>
  );
}
