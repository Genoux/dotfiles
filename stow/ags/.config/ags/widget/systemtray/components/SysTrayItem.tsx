import Tray from "gi://AstalTray"
import Hyprland from "gi://AstalHyprland"

interface SysTrayItemProps {
  item: Tray.TrayItem
}

export default function SysTrayItem({ item }: SysTrayItemProps) {
  const hypr = Hyprland.get_default();
  const handleClick = () => {
    try {
      item.activate(0, 0)
      hypr.dispatch("focuswindow", `class:${item.title}`)
    } catch (error) {
      console.log("Failed to activate tray item:", error)
    }
  }

  return (
    <button
      className="systray-item"
      onClicked={handleClick}
    >
      <icon gicon={item.gicon} />
    </button>
  )
}