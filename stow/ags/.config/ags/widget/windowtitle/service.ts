import Hyprland from "gi://AstalHyprland";
import { createBinding, createState } from "ags";

// Hyprland service (guarded)
let hypr: any = null;
try {
  hypr = Hyprland.get_default();
} catch {}

// State for triggering workspace updates
const [workspaceUpdateState, setWorkspaceUpdateState] = createState(0);

function triggerWorkspaceUpdate() {
  setWorkspaceUpdateState(prev => prev + 1);
}

// Reactive binding to the focused client
let __client: any;
if (hypr) {
  __client = createBinding(hypr, "focusedClient");
} else {
  const [client] = createState<any>(null);
  __client = client;
}
export const client = __client;

// Combined reactive data for WindowTitle component
let __windowTitleData: any;
if (hypr) {
  __windowTitleData = workspaceUpdateState(() => {
    const client = __client.get();
    const workspace = hypr.get_focused_workspace();
    return {
      client,
      workspace
    };
  });
} else {
  const [data] = createState<any>({ client: null, workspace: null });
  __windowTitleData = data;
}
export const windowTitleData = __windowTitleData;

// Auto-title functionality for empty workspaces
if (hypr) {
  try {
    // Listen for workspace and client changes to trigger updates
    hypr.connect("workspace-added", triggerWorkspaceUpdate);
    hypr.connect("workspace-removed", triggerWorkspaceUpdate);
    hypr.connect("client-added", triggerWorkspaceUpdate);
    hypr.connect("client-removed", triggerWorkspaceUpdate);
    hypr.connect("client-moved", triggerWorkspaceUpdate);

    // Subscribe to client changes to trigger workspace updates
    __client.subscribe(triggerWorkspaceUpdate);

    hypr.connect("client-added", (_hypr: any, client: any) => {
      // Get the workspace this client was added to
      const workspace = client.workspace;
      if (!workspace) return;

      // Check if this was the first client on the workspace (making it no longer empty)
      const clients = hypr.get_clients().filter((c: any) =>
        c.workspace?.id === workspace.id
      );

      // If this is the first client on this workspace, auto-set title
      if (clients.length === 1) {
        const title = client.title || client.class || "Unknown";
        // Set custom workspace title using hyprctl
        hypr.message_async(`dispatch renameworkspace ${workspace.id},${title}`, () => {
          triggerWorkspaceUpdate();
        });
      }
    });
  } catch (e) {
    console.warn("Failed to connect to client-added event:", e);
  }
}
