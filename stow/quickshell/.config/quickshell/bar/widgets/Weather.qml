import QtQuick
import qs
import qs.config
import qs.components
import qs.services

Button {
    id: root

    required property var barWindow

    property bool forecastLoaded: false

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

        // Forecast layout is only worth building once the popover is actually
        // opened; skips eager per-monitor instantiation at startup.
        Loader {
            active: root.forecastLoaded
            sourceComponent: forecastComponent
        }
    }

    Connections {
        target: popover

        function onOpenChanged() {
            if (popover.open)
                root.forecastLoaded = true;
        }
    }

    Component {
        id: forecastComponent

        WeatherPopover {
            active: popover.open
        }
    }
}
