import { Button } from "../../../lib/components";
import Icon from "../../../components/Icon";
import { openSystemMenu } from "../service";

export function SystemMenuButton() {
    return (
        <Button onClicked={openSystemMenu}>
            <Icon icon="system-shutdown-symbolic" />
        </Button>
    );
}
