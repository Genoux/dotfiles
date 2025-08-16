import Hyprland from "gi://AstalHyprland";
import { createBinding, createState } from "ags";

// Hyprland service (guarded)
let hypr: any = null;
try {
  hypr = Hyprland.get_default();
} catch {}

// Reactive binding to the focused client or fallback state
let __client: any;
if (hypr) {
  __client = createBinding(hypr, "focusedClient");
} else {
  const [client] = createState<any>(null);
  __client = client;
}
export const client = __client;
