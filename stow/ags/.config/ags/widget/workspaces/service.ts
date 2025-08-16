import Hyprland from "gi://AstalHyprland"
import { createBinding, createState } from "ags"

// Hyprland service (guarded)
let hypr: any = null;
try {
  hypr = Hyprland.get_default();
} catch {}

const [workspaceState, setWorkspaceState] = createState(0)

function triggerUpdate() {
  setWorkspaceState(prev => prev + 1)
}

// Function to get filtered and sorted workspaces
const getWorkspaces = () => {
  if (!hypr) return [];
  try {
    return hypr.get_workspaces()
      .filter((ws: any) => ws.id > 0) // Filter out special workspaces (negative IDs)
      .sort((a: any, b: any) => a.id - b.id) // Sort by workspace ID
  } catch {
    return [];
  }
}

// Create reactive workspaces that updates when state changes
const workspaces = workspaceState(() => getWorkspaces())

// Listen to workspace and client changes (guarded)
try {
  hypr?.connect("workspace-added", triggerUpdate);
  hypr?.connect("workspace-removed", triggerUpdate);
} catch {}

// Reactive focused workspace (guarded)
let __focusedWorkspace: any;
if (hypr) {
  __focusedWorkspace = createBinding(hypr, "focusedWorkspace");
} else {
  const [focused] = createState<any>(null);
  __focusedWorkspace = focused;
}
const focusedWorkspace = __focusedWorkspace;

export { hypr, workspaces, focusedWorkspace }