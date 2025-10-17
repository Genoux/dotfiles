import { createState } from "ags";
import { hypr, focusedWorkspace, getWorkspaces } from "../../lib/hyprland";

// Simple reactive trigger for workspace list updates
const [workspacesTrigger, setWorkspacesTrigger] = createState(0);

// Reactive workspaces list
export const workspaces = workspacesTrigger(() => getWorkspaces());

// Re-export from shared lib
export { focusedWorkspace, hypr };

// Listen to workspace changes
if (hypr) {
  hypr.connect("workspace-added", () => setWorkspacesTrigger((v) => v + 1));
  hypr.connect("workspace-removed", () => setWorkspacesTrigger((v) => v + 1));
}
