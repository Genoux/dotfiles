import Hyprland from "gi://AstalHyprland";
import { createBinding, createState } from "ags";

// Shared Hyprland service instance with proper guard
let hypr: Hyprland.Hyprland | null = null;

try {
  hypr = Hyprland.get_default();
} catch (e) {
  console.warn("Hyprland not available:", e);
}

export { hypr };

// Common reactive bindings with fallback to empty state when hypr is unavailable
export const focusedWorkspace = hypr
  ? createBinding(hypr, "focusedWorkspace")
  : createState<Hyprland.Workspace | null>(null)[0];

export const focusedClient = hypr
  ? createBinding(hypr, "focusedClient")
  : createState<Hyprland.Client | null>(null)[0];

// Helper to get workspaces sorted by ID
export function getWorkspaces() {
  if (!hypr) return [];

  return hypr
    .get_workspaces()
    .filter((ws) => ws.id > 0) // Exclude special workspaces
    .sort((a, b) => a.id - b.id);
}

// Helper to check if workspace has clients
export function workspaceHasClients(workspaceId: number): boolean {
  if (!hypr) return false;

  return hypr.get_clients().some((c) => c.workspace?.id === workspaceId);
}
