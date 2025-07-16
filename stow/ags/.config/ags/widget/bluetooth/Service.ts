import { Variable, exec, execAsync } from "astal"
import Bluetooth from "gi://AstalBluetooth"

const bluetooth = Bluetooth.get_default()

export const bluetoothDevices = Variable(bluetooth.get_devices())
export const bluetoothEnabled = Variable(bluetooth.get_is_powered())
export const connectingDevices = Variable(new Set<string>())
export const isScanning = Variable(false) // Manual tracking since API doesn't expose it reliably
export const isExpanded = Variable(false) // Controls dropdown visibility

bluetooth.connect("device-added", () => {
    bluetoothDevices.set(bluetooth.get_devices())
})

bluetooth.connect("device-removed", () => {
    bluetoothDevices.set(bluetooth.get_devices())
})

bluetooth.connect("notify::powered", () => {
    bluetoothEnabled.set(bluetooth.get_is_powered())
})

// Remove the discovering listener since the method doesn't exist
// bluetooth.connect("notify::discovering", () => {
//     isScanning.set(bluetooth.get_discovering())
// })

// Helper function to send notifications (optional - only for important events)
function sendNotification(title: string, body: string, icon: string = "bluetooth-active-symbolic", important: boolean = false) {
    if (important) {
        execAsync(`notify-send "${title}" "${body}" --icon="${icon}"`)
            .catch(err => console.error("Failed to send notification:", err))
    }
}

let isToggling = false

export async function toggleBluetooth() {
    if (isToggling) return // Prevent multiple rapid toggles
    
    isToggling = true
    const currentState = bluetooth.get_is_powered()
    
    try {
        // Use bluetoothctl for more reliable toggling
        if (currentState) {
            await execAsync("bluetoothctl power off")
        } else {
            await execAsync("bluetoothctl power on")
        }
        console.log(`Bluetooth ${!currentState ? 'enabled' : 'disabled'}`)
        
        // Give time for the state to update
        setTimeout(() => {
            bluetoothEnabled.set(bluetooth.get_is_powered())
        }, 500)
        
    } catch (error) {
        console.error("Failed to toggle Bluetooth:", error)
        sendNotification("Bluetooth Error", "Failed to toggle Bluetooth", "dialog-error-symbolic", true)
    } finally {
        // Re-enable toggling after 1 second
        setTimeout(() => {
            isToggling = false
        }, 1000)
    }
}

export function toggleExpanded() {
    isExpanded.set(!isExpanded.get())
}

export async function connectDevice(device: any) {
    const deviceName = device.name || "Unknown Device"
    const deviceAddress = device.address
    const isConnected = device.connected
    const isPaired = device.paired
    
    console.log("Device name:", deviceName)
    console.log("Device address:", deviceAddress)
    console.log("Device connected:", isConnected)
    console.log("Device paired:", isPaired)
    
    if (!deviceAddress) {
        console.error("Device has no address")
        sendNotification("Bluetooth Error", "Device has no address", "dialog-error-symbolic")
        return
    }
    
    // Add device to connecting set
    const connecting = connectingDevices.get()
    connecting.add(deviceAddress)
    connectingDevices.set(new Set(connecting))
    
    try {
        if (!isPaired) {
            // Pair the device first (only for new devices in pairing mode)
            console.log(`Pairing with ${deviceName}...`)
            await execAsync(`bluetoothctl pair ${deviceAddress}`)
            console.log(`Paired with ${deviceName}`)
            
            // After pairing, try to connect
            console.log(`Connecting to ${deviceName}...`)
            await execAsync(`bluetoothctl connect ${deviceAddress}`)
            console.log(`Connected to ${deviceName}`)
        } else if (isConnected) {
            // Disconnect the paired device
            console.log(`Disconnecting from ${deviceName}...`)
            await execAsync(`bluetoothctl disconnect ${deviceAddress}`)
            console.log(`Disconnected from ${deviceName}`)
        } else {
            // Connect to the paired device (this is the main use case)
            console.log(`Connecting to ${deviceName}...`)
            await execAsync(`bluetoothctl connect ${deviceAddress}`)
            console.log(`Connected to ${deviceName}`)
        }
    } catch (error) {
        console.error(`Failed to handle device ${deviceName}:`, error)
        
        let action = "connect to"
        if (!isPaired) action = "pair with"
        else if (isConnected) action = "disconnect from"
        
        sendNotification("Bluetooth Error", `Failed to ${action} ${deviceName}`, "dialog-error-symbolic", true)
    } finally {
        // Remove device from connecting set
        const connecting = connectingDevices.get()
        connecting.delete(deviceAddress)
        connectingDevices.set(new Set(connecting))
    }
}

export function isDeviceConnecting(device: any): boolean {
    return connectingDevices.get().has(device.address)
}

export async function toggleScan() {
    try {
        const currentlyScanning = isScanning.get()
        
        if (currentlyScanning) {
            console.log("Stopping Bluetooth scan...")
            await execAsync("bluetoothctl scan off")
            isScanning.set(false)
        } else {
            console.log("Starting Bluetooth scan...")
            execAsync("bluetoothctl scan on") // Don't await this as it runs continuously
            isScanning.set(true)
            
            // Auto-stop scan after 30 seconds
            setTimeout(() => {
                if (isScanning.get()) {
                    execAsync("bluetoothctl scan off")
                    isScanning.set(false)
                    console.log("Scan completed")
                }
            }, 30000)
        }
    } catch (error) {
        console.error("Failed to toggle scan:", error)
        isScanning.set(false)
        sendNotification("Bluetooth Error", `Failed to toggle scan`, "dialog-error-symbolic", true)
    }
}

export function getBluetoothIcon() {
    if (!bluetooth.get_is_powered()) return "bluetooth-disabled-symbolic"
    return "bluetooth-active-symbolic"
}

export { bluetooth }