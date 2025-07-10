import { Variable } from "astal"
import Hyprland from "gi://AstalHyprland"

// Widget Logic - 100% State & Business Logic
let hypr: any = null
export const updateTrigger = Variable(0)
let titleSignalId: number | null = null

function triggerUpdate() {
  updateTrigger.set(updateTrigger.get() + 1)
}

// Initialize Hyprland connection safely
try {
  hypr = Hyprland.get_default()
  
  // Listen to window focus events
  hypr.connect("notify::focused-client", () => {
    // Clean up previous listener
    if (titleSignalId !== null && hypr.focusedClient) {
      hypr.focusedClient.disconnect(titleSignalId)
      titleSignalId = null
    }

    const currentClient = hypr.focusedClient
    if (currentClient) {
      titleSignalId = currentClient.connect("notify::title", triggerUpdate)
    }
    triggerUpdate()
  })

  // Listen to client changes
  hypr.connect("client-added", triggerUpdate)
  hypr.connect("client-removed", triggerUpdate)
  
} catch (error) {
  console.warn("Hyprland not available, window title will not be functional:", error)
  // Set a default trigger to prevent crashes
  updateTrigger.set(0)
}

// Export hyprland instance
export { hypr }