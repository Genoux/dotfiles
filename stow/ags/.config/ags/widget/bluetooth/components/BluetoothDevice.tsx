import { Gtk } from "astal/gtk3"
import { bind } from "astal"
import { connectDevice, isDeviceConnecting, connectingDevices } from "../Service"

interface BluetoothDeviceProps {
    device: any
}

export default function BluetoothDevice({ device }: BluetoothDeviceProps) {
    const getDeviceIcon = (device: any, isConnecting: boolean) => {
        if (isConnecting) return "process-working-symbolic"
        
        if (device.paired && device.connected) return "bluetooth-active-symbolic"
        if (device.paired) return "bluetooth-symbolic" 
        return "bluetooth-disabled-symbolic"
    }

    const getDeviceStatus = (device: any, isConnecting: boolean) => {        
        if (isConnecting) {
            if (!device.paired) return "Pairing..."
            return device.connected ? "Disconnecting..." : "Connecting..."
        }
        if (device.connected) return "Connected"
        if (device.paired) return "Disconnected"
        return "Click to pair"
    }

    return (
        <button
            className={bind(connectingDevices).as(connecting => 
                `bluetooth-device ${connecting.has(device.address) ? 'connecting' : ''}`
            )}
            on_clicked={() => connectDevice(device)}
            sensitive={bind(connectingDevices).as(connecting => 
                !connecting.has(device.address)
            )}
        >
            <box spacing={8} halign={Gtk.Align.FILL}>
                <icon 
                    icon={bind(connectingDevices).as(connecting => 
                        getDeviceIcon(device, connecting.has(device.address))
                    )}
                    className={bind(connectingDevices).as(connecting => {
                        const isConnecting = connecting.has(device.address)
                        if (isConnecting) return "bluetooth-device-icon connecting"
                        return `bluetooth-device-icon ${device.connected ? 'connected' : 'paired'}`
                    })}
                />
                <box 
                    orientation={Gtk.Orientation.VERTICAL}
                    halign={Gtk.Align.START}
                    hexpand={true}
                >
                    <label 
                        label={device.name || "Unknown Device"}
                        className="bluetooth-device-name"
                        halign={Gtk.Align.START}
                    />
                    <label 
                        label={bind(connectingDevices).as(connecting => 
                            getDeviceStatus(device, connecting.has(device.address))
                        )}
                        className={bind(connectingDevices).as(connecting => {
                            const isConnecting = connecting.has(device.address)
                            if (isConnecting) return "bluetooth-device-status connecting"
                            return `bluetooth-device-status ${device.connected ? 'connected' : 'paired'}`
                        })}
                        halign={Gtk.Align.START}
                    />
                </box>
                {device.connected && (
                    <icon 
                        icon="object-select-symbolic"
                        className="bluetooth-connected-indicator"
                    />
                )}
            </box>
        </button>
    )
}