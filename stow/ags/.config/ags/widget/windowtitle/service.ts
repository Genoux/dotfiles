import Hyprland from "gi://AstalHyprland";
import { createBinding, createState } from "ags";

let hypr: Hyprland.Hyprland | null = null;

try {
  hypr = Hyprland.get_default();
} catch (e) {
  console.warn("Hyprland not available:", e);
}

export const focusedClient = hypr
  ? createBinding(hypr, "focusedClient")
  : null;

// Use counter to force reactive updates when client properties change
const [updateId, setUpdateId] = createState(0);
const forceUpdate = () => setUpdateId((id) => id + 1);

// Track client handlers with their associated client
let trackedClient: Hyprland.Client | null = null;
let clientHandlers: number[] = [];

const setupClientWatchers = (client: Hyprland.Client | null) => {
  // Disconnect old handlers from the tracked client
  if (clientHandlers.length > 0 && trackedClient) {
    try {
      clientHandlers.forEach((handlerId) => trackedClient!.disconnect(handlerId));
    } catch (e) {
      // Client might be destroyed, ignore
    }
  }
  clientHandlers = [];
  trackedClient = null;

  // Connect new handlers
  if (client) {
    clientHandlers = [
      client.connect("notify::title", forceUpdate),
      client.connect("notify::class", forceUpdate),
    ];
    trackedClient = client;
  }
  
  forceUpdate();
};

// Listen to focused client changes
if (hypr) {
  hypr.connect("notify::focused-client", () => {
    setupClientWatchers(hypr.get_focused_client());
  });
  
  // Set up initial watchers
  setupClientWatchers(hypr.get_focused_client());
}

// Export reactive getters
export const clientTitle = updateId(() => {
  if (!focusedClient) return "";
  const client = focusedClient.get();
  return client?.get_title() || "";
});

export const clientClass = updateId(() => {
  if (!focusedClient) return "";
  const client = focusedClient.get();
  return client?.get_class() || "";
});
