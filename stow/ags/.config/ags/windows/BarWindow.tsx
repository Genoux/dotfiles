import Bar from "../widget/Bar";
import { Gdk } from "ags/gtk4";

interface BarWindowProps {
    gdkmonitor: Gdk.Monitor;
}

export default function BarWindow({ gdkmonitor }: BarWindowProps) {
    return Bar(gdkmonitor);
}
