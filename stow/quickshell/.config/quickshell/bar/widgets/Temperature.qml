import qs
import qs.config
import qs.components
import qs.services as Services

Button {
    id: root

    required property var barWindow

    iconSource: IconRegistry.temperatureIcon(Services.Temperature.icon)
    text: Services.Temperature.value
    fontSize: StyleBar.labelFontSize
    interactive: true
    active: popover.open
    // The thermometer is much narrower than its fixed icon box, leaving more
    // invisible space on its right than the weather glyph. Pull the label in by
    // one spacing step so the visible ink-to-text gap matches Weather.
    iconTextSpacing: StyleTokens.space2
    onClicked: popover.toggle()

    BarPopover {
        id: popover

        barWindow: root.barWindow
        anchorItem: root

        SystemMonitorPopover {
            active: popover.open
            onBtopRequested: {
                popover.dismissNow()
                ShellActions.launchOrFocus("btop", "btop", "htop")
            }
        }
    }
}
