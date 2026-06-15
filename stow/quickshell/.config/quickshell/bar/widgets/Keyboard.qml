import qs
import qs.config
import qs.components
import qs.services as Services

Button {
    text: Services.Keyboard.layout
    foreground: Colors.base05
    fontFamily: StyleTokens.fontSans
    fontSize: StyleTokens.fontSizeSm
    paddingHorizontal: StyleControl.buttonPaddingHorizontal + 2
    interactive: true

    onClicked: ShellActions.switchKeyboardLayout("current")
}
