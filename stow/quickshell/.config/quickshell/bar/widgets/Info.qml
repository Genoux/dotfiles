import qs.config
import qs.components

Button {
    iconSource: IconRegistry.barControlIcon("info")
    interactive: true
    onClicked: ShellActions.launchOrFocus("system-info", "fastfetch", "system-info")
}
