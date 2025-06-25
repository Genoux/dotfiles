import { Gtk } from "astal/gtk3"
import { systemTemps } from "../Service"
import { bind } from "astal"

// UI Component with theme icon
export default function SystemTempDisplay() {
    return (
        <button
            className="system-temp-display"
            halign={Gtk.Align.CENTER}
            tooltip_text="System temperatures (CPU/GPU)"
        >
            <box spacing={4}>
                <icon 
                    icon={bind(systemTemps).as(data => 
                        data.avgTemp >= 85 ? "temperature-symbolic" : "computer-symbolic"
                    )}
                />
                <label 
                    label={bind(systemTemps).as(data => 
                        data.avgTemp === 0 ? "" : `${data.avgTemp}°C`
                    )}
                />
            </box>
        </button>
    )
} 