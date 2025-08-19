import app from "ags/gtk4/app"
import style from "./styles/main.scss"
import Bar from "./widget/Bar"
import { MediaPopup } from "./widget/mediaplayer"  // ← import your popup window

app.start({
  css: style,
  main() {
    app.get_monitors().map(Bar)
    MediaPopup()
  },
})
