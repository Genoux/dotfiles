import qs
import qs.components
import qs.config
import qs.services as Services

Button {
    text: Services.Keyboard.layout
    foreground: Colors.base05
    fontFamily: StyleTokens.fontSans
    fontSize: StyleBar.labelFontSize
    interactive: true
    onClicked: ShellActions.switchKeyboardLayout("current")
}
