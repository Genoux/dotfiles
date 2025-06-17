import { Gtk } from "astal/gtk3"
import { bind } from "astal"
import { systemActions } from "../Service"
import { ConfirmationOverlay, confirmationVisible } from "./ConfirmationOverlay"

// =============================================================================
// System Control Component
// =============================================================================

interface SystemControlButtonProps {
    icon: string
    action: () => void
    className?: string
}

function SystemControlButton({ icon, action, className = "" }: SystemControlButtonProps) {
    return (
        <button
            className={`system-control-btn ${className}`}
            onClicked={action}
            hexpand
        >
            <icon icon={icon} />
        </button>
    )
}

export default function SystemControl() {
    return (
        <box className="system-control-container" vertical spacing={8}>
            <stack
                shown={bind(confirmationVisible).as(show => show ? "confirmation" : "controls")}
                transitionType={Gtk.StackTransitionType.SLIDE_UP}
                transitionDuration={200}
            >
                <box name="controls" className="system-controls" spacing={8} hexpand>
                    {systemActions.map((action, index) => (
                        <SystemControlButton
                            icon={action.icon}
                            action={action.action}
                            className={action.className}
                        />
                    ))}
                </box>
                
                <box name="confirmation" className="confirmation-container">
                    <ConfirmationOverlay />
                </box>
            </stack>
        </box>
    )
} 