import app from "ags/gtk4/app"
import style from "./styles/main.scss"
import Bar from "./widget/Bar"

app.start({
  css: style,
  main() {
    app.get_monitors().map(Bar)
  },
})
