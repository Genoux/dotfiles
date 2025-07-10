import { Variable, exec, subprocess } from "astal"
import GLib from "gi://GLib"

// Widget Logic - 100% State & Business Logic

// Variable to store the current keyboard language
export const keyboardLang = Variable("EN")

// Simple layout mapping
function mapLayout(layout: string): string {
    const map: { [key: string]: string } = {
        'us': 'EN',
        'fr': 'FR',
    }
    return map[layout.toLowerCase()] || layout.slice(0, 2).toUpperCase()
}

// Get current layout
function getCurrentLayout(): string {
    try {
        const devices = JSON.parse(exec("hyprctl devices -j"))
        const keyboard = devices.keyboards?.find((kb: any) => kb.main)
        return mapLayout(keyboard?.active_keymap || "us")
    } catch {
        return "EN"
    }
}

// Switch layout
export function switchKeyboardLayout() {
    try {
        const devices = JSON.parse(exec("hyprctl devices -j"))
        const keyboard = devices.keyboards?.find((kb: any) => kb.main)
        if (keyboard) {
            exec(`hyprctl switchxkblayout ${keyboard.name} next`)
        }
    } catch (error) {
        console.error("Failed to switch layout:", error)
    }
}

// Initialize
keyboardLang.set(getCurrentLayout())

// Listen for layout changes via socket
try {
    const instance = GLib.getenv("HYPRLAND_INSTANCE_SIGNATURE")
    const socketPath = `${GLib.getenv("XDG_RUNTIME_DIR")}/hypr/${instance}/.socket2.sock`
    
    subprocess(
        ["socat", "-u", `UNIX-CONNECT:${socketPath}`, "-"],
        (output) => {
            for (const line of output.trim().split('\n')) {
                if (line.startsWith('activelayout>>')) {
                    const layout = line.split(',')[1]
                    if (layout) {
                        keyboardLang.set(mapLayout(layout))
                    }
                }
            }
        }
    )
} catch {
    // Fallback to polling if socket fails
    keyboardLang.poll(3000, getCurrentLayout)
} 