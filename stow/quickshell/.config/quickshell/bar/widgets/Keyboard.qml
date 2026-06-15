import qs
import qs.config
import qs.components
import qs.services as Services

Button {
    text: Services.Keyboard.layout
    foreground: Colors.base05
    fontFamily: StyleTokens.fontSans
    fontSize: StyleTokens.fontSizeSm
    interactive: true
    onClicked: Services.Keyboard.switchLayout()
}
