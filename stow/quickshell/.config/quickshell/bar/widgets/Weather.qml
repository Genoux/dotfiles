import QtQuick
import qs
import qs.config
import qs.components
import qs.services

Button {
    id: root

    required property var barWindow

    iconSource: IconRegistry.weatherIcon(WeatherState.icon)
    iconColored: true
    text: WeatherState.temperature
    interactive: true
    active: popover.open
    onClicked: popover.open = !popover.open

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root

        WeatherPopover {
            active: popover.open
        }
    }
}
