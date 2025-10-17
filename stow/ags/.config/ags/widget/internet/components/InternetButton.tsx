import { Button } from "../../../lib/components";
import { connectionIcon, openInternetManager } from "../service";

export function InternetButton({ class: cls = "" }: { class?: string }) {
  return (
    <box class={`${cls}`}>
      <Button onClicked={openInternetManager}>
        <image iconName={connectionIcon((icon) => icon)} pixelSize={11} />
      </Button>
    </box>
  );
}
