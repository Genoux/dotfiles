import qs
import qs.config
import qs.components
import qs.services

InfoPill {
    iconText: WeatherState.icon
    iconFont: Style.fontEmoji
    iconVisible: WeatherState.icon.length > 0
    labelText: WeatherState.temperature
    onClicked: ShellActions.launchOrFocus("gnome-weather", "gnome-weather", "org.gnome.Weather")
}
