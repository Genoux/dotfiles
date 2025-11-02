import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";
import { connectionIcon, openInternetManager } from "../service";

export function InternetButton() {
  return (
    <Button onClicked={openInternetManager}>
      <Icon icon={connectionIcon((icon) => icon)} />
    </Button>
  );
}
