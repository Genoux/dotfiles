import qs
import qs.config
import qs.components
import qs.services

Button {
    iconGlyph: WeatherState.icon
    iconFont: StyleTokens.fontEmoji
    text: WeatherState.temperature
    interactive: true
    onClicked: ShellActions.launchOrFocus("gnome-weather", "gnome-weather", "org.gnome.Weather")
}
