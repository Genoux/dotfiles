import { Gtk } from "astal/gtk3"
import { weatherDisplay, weather, initializeWeather } from "../Service"

// UI Component - 100% Pure UI  
export default function WeatherDisplay() {
    return (
        <button
            className="weather-display"
            halign={Gtk.Align.CENTER}
            setup={(self) => {
                // Initialize weather loading when widget is set up
                initializeWeather();
            }}
        >
            <label label={weatherDisplay()} />
        </button>
    )
} 