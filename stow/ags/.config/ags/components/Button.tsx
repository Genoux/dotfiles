import { Gtk } from "ags/gtk4";

interface ButtonProps {
    icon?: string;
    label?: string;
    onClicked?: () => void;
    cssName?: string;
    tooltip?: string;
    active?: boolean;
    children?: any;
}

export default function Button({
    icon,
    label,
    onClicked,
    cssName = "",
    tooltip,
    active = false,
    children
}: ButtonProps) {
    return (
        <button
            cssName={`button ${active ? "active" : ""} ${cssName}`}
            onClicked={onClicked}
        >
            {children || (
                <>
                    {icon && <image iconName={icon} cssName="button-icon" pixelSize={14} />}
                    {label && <label label={label} cssName="button-label" />}
                </>
            )}
        </button>
    );
}
