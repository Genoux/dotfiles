import { openDotfilesMenu, getUpdateState } from "../service";
import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";
import { With } from "ags";
import { Gtk } from "ags/gtk4";

export function SystemDotfilesButton() {
  return (
    <With value={getUpdateState()}>
      {({ available }) => (
        <Button onClicked={openDotfilesMenu}>
          <box spacing={1}>
            <Icon icon="input-keyboard" />
                {available && (
                  <box valign={Gtk.Align.CENTER}>
                    <Icon cssName="wiggle" icon="task-process-4" size={8} />
                  </box>
                )}
          </box>
        </Button>
      )}
    </With>
  );
}

