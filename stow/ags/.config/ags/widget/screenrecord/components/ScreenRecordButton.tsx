import { Gtk } from "ags/gtk4";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";
import { isRecording, toggleRecording, RecordScope, isCurrentlyRecording } from "../service";

type MenuOption = {
  label: string;
  scope: RecordScope;
  withAudio: boolean;
};

const MENU_OPTIONS: MenuOption[] = [
  { label: "Record Region", scope: "region", withAudio: false },
  { label: "Record Region (Audio)", scope: "region", withAudio: true },
  { label: "Record Display", scope: "fullscreen", withAudio: false },
  { label: "Record Display (Audio)", scope: "fullscreen", withAudio: true },
];

function createMenuButton(label: string, onClick: () => void) {
  const button = new Gtk.Button({
    label,
    halign: Gtk.Align.FILL,
    hexpand: true,
  });

  // Get the label widget inside the button and align it left
  const child = button.get_child();
  if (child) {
    child.set_halign(Gtk.Align.START);
  }

  button.connect("clicked", onClick);
  return button;
}

function showMenu(widget: any) {
  if (!widget) return;

  const popover = new Gtk.Popover();
  popover.set_parent(widget);
  popover.set_autohide(true);
  popover.set_has_arrow(true);

  const content = new Gtk.Box({
    orientation: Gtk.Orientation.VERTICAL,
    spacing: 4,
  });

  MENU_OPTIONS.forEach((option) => {
    content.append(createMenuButton(option.label, () => {
      toggleRecording(option.scope, option.withAudio);
      popover.popdown();
    }));
  });

  popover.set_child(content);
  popover.popup();
}

export function ScreenRecordButton() {
  return (
    <box class={isRecording((active) => active ? "recording-indicator" : "")}>
      <Button
        visible={isRecording((active) => active)}
        onClicked={(self: any) => {
          // Synchronously check if recording is active right now
          if (isCurrentlyRecording()) {
            toggleRecording();
          } else {
            showMenu(self);
          }
        }}
      >
        <Icon icon={isRecording((active) => active ? "media-playback-stop-symbolic" : "media-record-symbolic")} />
      </Button>
    </box>
  );
}
