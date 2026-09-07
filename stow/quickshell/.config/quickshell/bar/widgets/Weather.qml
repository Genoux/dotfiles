import QtQuick
import qs
import qs.config
import qs.components
import qs.services

Button {
    id: root

    required property var barWindow

    text: IconRegistry.weatherEmoji(WeatherState.icon) + " " + WeatherState.temperature
    fontSize: StyleBar.labelFontSize
    interactive: true
    active: popover.open
    onClicked: popover.toggle()

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root

        // Keep the forecast built so its window has settled geometry before
        // the first reveal.
        WeatherPopover {
            active: popover.open
        }
    }
}
