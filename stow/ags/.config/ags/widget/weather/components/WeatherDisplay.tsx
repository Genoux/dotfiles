import { Gtk } from "astal/gtk3"
import { weatherDisplay, weather } from "../Service"

// UI Component - 100% Pure UI  
export default function WeatherDisplay() {
    return (
        <button
            className="weather-display"
            halign={Gtk.Align.CENTER}
        >
            <label label={weatherDisplay()} />
        </button>
    )
} 