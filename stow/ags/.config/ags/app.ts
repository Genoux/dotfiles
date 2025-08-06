import app from "ags/gtk4/app"
import style from "./styles/main.scss"
import Bar from "./widget/Bar"
import { MediaPanel } from "./widget/mediaplayer"  // ← import your popup window

app.start({
  css: style,
  main() {
    app.get_monitors().map(Bar)
    MediaPanel()   // ← Add here as a global, NOT as a child of Bar!
  },
})
