// stow/ags/.config/ags/widget/systemtray/components/SystemTray.tsx
import { bind, Variable } from "astal"
import Tray from "gi://AstalTray"
import SysTrayItem from "./SysTrayItem"

const tray = Tray.get_default()
export const trayItems = Variable(tray.get_items())

tray.connect("item-added", () => {
  trayItems.set(tray.get_items())
})

tray.connect("item-removed", () => {
  trayItems.set(tray.get_items())
})

export default function SystemTray() {
  return (
    <box 
      className="system-tray" 
      spacing={4}
    >
      {bind(trayItems).as(items =>
        items.map((item) => (
          <SysTrayItem item={item} />
        ))
      )}
    </box>
  )
}