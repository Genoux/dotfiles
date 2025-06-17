import { App } from "astal/gtk3"
import style from "./styles/main.scss"
import Bar from "./widget/Bar"
import { NotificationPopup } from "./widget/notifications"
import ModularAppLauncher from "./widget/applauncher/ModularAppLauncher"
import { OSD } from "./widget/osd"
//import initHyprland from "./widget/utils/Hyprland"

App.start({
    css: style,
    main() {
        App.get_monitors().map(monitor => {
            Bar({ gdkmonitor: monitor })
            NotificationPopup(monitor)
            OSD(monitor)
        })
        ModularAppLauncher()
    },
})
