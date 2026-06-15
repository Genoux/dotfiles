import qs.config
import qs.components

Button {
    iconName: "emblem-favorite-symbolic"
    interactive: true
    onClicked: ShellActions.launchOrFocus("system-info", "fastfetch", "system-info")
}
