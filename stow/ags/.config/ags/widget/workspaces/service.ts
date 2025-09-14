import Hyprland from "gi://AstalHyprland"
import { createBinding, createState } from "ags"

// Hyprland service (guarded)
let hypr: any = null;
try {
  hypr = Hyprland.get_default();
} catch {}

const [workspaceState, setWorkspaceState] = createState(0)
const [clientState, setClientState] = createState(0)

function triggerWorkspaceUpdate() {
  setWorkspaceState(prev => prev + 1)
}

function triggerClientUpdate() {
  setClientState(prev => prev + 1)
}

// Function to get filtered and sorted workspaces
const getWorkspaces = () => {
  if (!hypr) return [];
  try {
    // Simply return workspaces that exist - Hyprland handles creation/destruction
    return hypr.get_workspaces()
      .filter((ws: any) => ws.id > 0) // Filter out special workspaces (negative IDs)
      .sort((a: any, b: any) => a.id - b.id); // Sort by workspace ID
  } catch {
    return [];
  }
}

// Get workspace client counts for better state tracking
const getWorkspaceClients = () => {
  if (!hypr) return {};
  try {
    const clients = hypr.get_clients();
    const clientCounts: { [key: number]: number } = {};
    
    clients.forEach((client: any) => {
      const wsId = client.workspace?.id;
      if (wsId && wsId > 0) {
        clientCounts[wsId] = (clientCounts[wsId] || 0) + 1;
      }
    });
    
    return clientCounts;
  } catch {
    return {};
  }
}

// Create reactive workspaces that updates when state changes
const workspaces = workspaceState(() => {
  clientState(() => {}); // Also react to client changes
  return getWorkspaces();
})

const workspaceClients = clientState(() => getWorkspaceClients())

// Listen to workspace and client changes (guarded)
if (hypr) {
  try {
    // Workspace events
    hypr.connect("workspace-added", triggerWorkspaceUpdate);
    hypr.connect("workspace-removed", triggerWorkspaceUpdate);

    // Client events (for tracking which workspaces have windows)
    hypr.connect("client-added", triggerClientUpdate);
    hypr.connect("client-removed", triggerClientUpdate);
    hypr.connect("client-moved", triggerClientUpdate);
  } catch (e) {
    console.warn("Failed to connect to Hyprland events:", e);
  }
}

// Reactive focused workspace (guarded)
let __focusedWorkspace: any;
if (hypr) {
  __focusedWorkspace = createBinding(hypr, "focusedWorkspace");
} else {
  const [focused] = createState<any>(null);
  __focusedWorkspace = focused;
}
const focusedWorkspace = __focusedWorkspace;

export { hypr, workspaces, focusedWorkspace, workspaceClients }