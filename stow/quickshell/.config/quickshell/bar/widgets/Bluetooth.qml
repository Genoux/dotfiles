import qs.components
import qs.config

Button {
    iconName: "bluetooth-active-symbolic"
    interactive: true
    onClicked: ShellActions.launchOrFocus("bluetui", "bluetui", "bluetooth")
}
