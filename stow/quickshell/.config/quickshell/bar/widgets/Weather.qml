import qs
import qs.config
import qs.components
import qs.services

Button {
    iconSource: IconRegistry.weatherIcon(WeatherState.icon)
    iconColored: true
    text: WeatherState.temperature
    interactive: true
    onClicked: ShellActions.launchOrFocus("gnome-weather", "gnome-weather", "org.gnome.Weather")
}
