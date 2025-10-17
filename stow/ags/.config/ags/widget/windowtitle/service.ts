import { hypr } from "../../lib/hyprland";
import { createState } from "ags";
import Hyprland from "gi://AstalHyprland";

// Use counter to force reactive updates when title changes
// (same Client object reference doesn't trigger updates otherwise)
const [updateId, setUpdateId] = createState(0);

const forceUpdate = () => setUpdateId((id) => id + 1);

if (hypr) {
  let titleHandlerId: number | null = null;
  let previousClient: Hyprland.Client | null = null;

  const setupTitleWatcher = (client: Hyprland.Client | null) => {
    // Disconnect previous title handler
    if (titleHandlerId !== null && previousClient) {
      previousClient.disconnect(titleHandlerId);
      titleHandlerId = null;
    }

    // Watch for title changes on current client
    if (client) {
      titleHandlerId = client.connect("notify::title", forceUpdate);
      previousClient = client;
    }
  };

  hypr.connect("notify::focused-client", () => {
    setupTitleWatcher(hypr!.get_focused_client());
    forceUpdate();
  });

  // Setup watcher for initial client
  setupTitleWatcher(hypr.get_focused_client());
}

export const client = updateId(() => hypr?.get_focused_client() || null);
