import { App } from "astal/gtk3"
import style from "./styles/main.scss"
import Bar from "./widget/Bar"
import { NotificationPopup } from "./widget/notifications"
import { AppLauncher } from "./widget/applauncher"
import { OSD } from "./widget/osd"

App.start({
    css: style,
    main() {
        App.get_monitors().map(monitor => {
            Bar({ gdkmonitor: monitor })
            NotificationPopup(monitor)
            OSD(monitor)
        })
        AppLauncher()
    },
})
