import { connectionIcon, openInternetManager } from "../service";

export function InternetButton({
  class: cls = "",
}: {
  class?: string;
}) {
  return (
    <box class={`${cls}`}>
      <button onClicked={openInternetManager}>
        <image
          iconName={connectionIcon((icon) => icon)}
          pixelSize={11}
        />
      </button>
    </box>
  );
}