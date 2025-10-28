import { Button } from "../../../lib/components";
import { openSystemMenu } from "../service";

export function SystemMenuButton({ class: cls = "" }: { class?: string }) {
    return (
        <box class={`${cls}`}>
            <Button onClicked={openSystemMenu}>
                <image iconName="system-shutdown-symbolic" pixelSize={13} />
            </Button>
        </box>
    );
}
