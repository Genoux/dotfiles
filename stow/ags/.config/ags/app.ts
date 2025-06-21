import { App } from "astal/gtk3"
import style from "./styles/main.scss"
import Bar from "./widget/Bar"
import { NotificationPopup } from "./widget/notifications"
import AppLauncher from "./widget/applauncher/AppLauncher"
import { OSD } from "./widget/osd"
import { windowManager } from "./widget/utils"
//import initHyprland from "./widget/utils/Hyprland"

App.start({
    css: style,
    main() {
        // Initialize WindowManager early for workspace change detection
        windowManager
        
        App.get_monitors().map(monitor => {
            Bar({ gdkmonitor: monitor })
            NotificationPopup(monitor)
            OSD(monitor)
        })
        AppLauncher()
    },
})
