import { Variable } from "astal"
import Hyprland from "gi://AstalHyprland"

// Widget Logic - 100% State & Business Logic
let hypr: any = null

// Create a map to track client count per workspace
export const workspaceClients = Variable(new Map())

// Function to update workspace client counts
const updateWorkspaceClients = () => {
    if (!hypr) return
    
    const clientMap = new Map()
    const workspaces = hypr.get_workspaces()
    
    workspaces.forEach(ws => {
        if (ws.id > 0) { // Only normal workspaces
            const clients = ws.get_clients()
            clientMap.set(ws.id, clients.length)
        }
    })
    
    workspaceClients.set(clientMap)
}

// Initialize Hyprland connection safely
try {
    hypr = Hyprland.get_default()
    
    // Initial update
    updateWorkspaceClients()
    
    // Listen to all relevant events
    const events = [
        "client-added",
        "client-removed",
        "client-moved",
        "workspace-added",
        "workspace-removed"
    ]
    
    events.forEach(event => {
        hypr.connect(event, updateWorkspaceClients)
    })
    
} catch (error) {
    console.warn("Hyprland not available, workspaces will not be functional:", error)
    // Set empty map as fallback
    workspaceClients.set(new Map())
}

// Export hyprland instance for UI
export { hypr }