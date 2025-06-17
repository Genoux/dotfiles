import { Gtk } from "astal/gtk3"
import { bind } from "astal"
import { workspaceClients, hypr } from "../Service"

// UI Component - 100% Pure UI
export default function Workspaces() {
    return (
        <box className="workspaces">
            {bind(workspaceClients).as(clientMap => {
                const workspaces = hypr.get_workspaces()
                    .filter(ws => ws.id > 0)
                    .sort((a, b) => a.id - b.id)
                
                return workspaces.map(ws => {
                    const clientCount = clientMap.get(ws.id) || 0
                    const isOccupied = clientCount > 0
                    
                    return (
                        <button
                            className={bind(hypr, "focusedWorkspace").as(focused => {
                                const isFocused = focused?.id === ws.id
                                let classes = ["workspace"]
                                if (isFocused) classes.push("focused")
                                if (isOccupied) classes.push("occupied")
                                if (isOccupied && !isFocused) classes.push("active")
                                return classes.join(" ")
                            })}
                            onClicked={() => ws.focus()}
                            // tooltip_text={`Workspace ${ws.id}${isOccupied ? ` (${clientCount} windows)` : ""}`}
                        >
                            {bind(hypr, "focusedWorkspace").as(focused => {
                                const isFocused = focused?.id === ws.id
                                
                                if (isOccupied) {
                                    const dotClass = isFocused ? "focused-dot" : "occupied-dot"
                                    return (
                                        <box 
                                            className={`workspace-dot ${dotClass}`} 
                                            widthRequest={9} 
                                            heightRequest={9}
                                        />
                                    )
                                } else {
                                    return (
                                        <label
                                            className="workspace-number"
                                            label={ws.id.toString()}
                                            halign={Gtk.Align.CENTER}
                                            valign={Gtk.Align.CENTER}
                                            heightRequest={12}
                                            widthRequest={12}
                                        />
                                    )
                                }
                            })}
                        </button>
                    )
                })
            })}
        </box>
    )
} 