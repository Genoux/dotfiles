import { Accessor } from "ags";

interface IconProps {
    icon: string | Accessor<string>;
    size?: number;
    cssName?: string;
    [key: string]: any;
}

export default function Icon({
    icon,
    size = 14,
    cssName = "",
    ...props
}: IconProps) {
    return (
        <image
            iconName={icon}
            pixelSize={size}
            cssName={cssName}
            {...props}
        />
    );
}
