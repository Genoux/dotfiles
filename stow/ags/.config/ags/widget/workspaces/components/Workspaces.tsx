import { Gtk } from "astal/gtk3"
import { bind } from "astal"
import { workspaceClients, hypr } from "../Service"

// UI Component - 100% Pure UI
export default function Workspaces() {
  return (
    <box className="workspaces" spacing={2}>
      {bind(workspaceClients).as(clientMap => {
        const workspaces = hypr.get_workspaces()
          .filter(ws => ws.id > 0)
          .sort((a, b) => a.id - b.id)

        // Find the highest workspace that has windows or is focused
        const focusedWs = hypr.get_focused_workspace()
        const maxOccupiedId = Math.max(
          ...Array.from(clientMap.keys()),
          focusedWs?.id || 1
        )
        
        // Only show workspaces up to max occupied + 1
        const relevantWorkspaces = workspaces.filter(ws => ws.id <= maxOccupiedId + 1)

        return relevantWorkspaces.map(ws => {
          const clientCount = clientMap.get(ws.id) || 0
          const isOccupied = clientCount > 0

          return (
            <button
              className={bind(hypr, "focusedWorkspace").as(focused => {
                const isFocused = focused?.id === ws.id
                let classes = ["workspace"]
                if (isFocused) classes.push("focused")
                return classes.join(" ")
              })}
              onClicked={() => ws.focus()}
            >
              {isOccupied ? (
                <box
                  heightRequest={6}
                  widthRequest={2}
                  hexpand={false}
                  vexpand={false}
                  halign={Gtk.Align.CENTER}
                  valign={Gtk.Align.CENTER}
                  className={bind(hypr, "focusedWorkspace").as(focused => {
                    const isFocused = focused?.id === ws.id
                    return isFocused ? "dot focused" : "dot"
                  })}
                />
              ) : (
                <label
                  className="number"
                  label={ws.id.toString()}
                  halign={Gtk.Align.CENTER}
                  valign={Gtk.Align.CENTER}
                />
              )}
            </button>
          )
        })
      })}
    </box>
  )
} 