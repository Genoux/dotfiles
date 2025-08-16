import Tray from "gi://AstalTray";
import { createPoll } from "ags/time";
import { createBinding } from "ags";



const tray = Tray.get_default();
const items = tray.get_items();
export const trayItems = createBinding(tray, "items")
tray.connect("item-added", (_, id) => {
    print("added:", id);
    const items = tray.get_items();
    print("items.length:", items.length);
    for (const item of items) {
      print("item typeof:", typeof item);
      print("item GType:", item.constructor?.name);
    }
  });
  

tray.connect("item-removed", (k, v) => {
  console.log("item-removed", k, v)
})
