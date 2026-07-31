import QtQuick
import qs
import qs.config
import qs.components
import qs.services

Button {
    id: root

    required property var barWindow

    iconSource: IconRegistry.weatherIcon(WeatherState.icon)
    text: WeatherState.temperature
    interactive: true
    iconTextSpacing: 0
    active: popover.open
    onClicked: popover.toggle()

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root

        WeatherPopover {
            active: popover.open
        }
    }
}
