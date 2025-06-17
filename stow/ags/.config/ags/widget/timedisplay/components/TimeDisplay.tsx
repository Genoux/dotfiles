import { Gtk } from "astal/gtk3"
import { time } from "../Service"

// UI Component - 100% Pure UI
export default function TimeDisplay() {
    return (
        <button
            className="time-display"
            halign={Gtk.Align.CENTER}
        >
            <label label={time()} />
        </button>
    )
} 