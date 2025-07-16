import { Gtk } from "astal/gtk3"
import { bind } from "astal"
import { bluetoothDevices, bluetoothEnabled, isScanning, isExpanded, toggleBluetooth, toggleScan, toggleExpanded, getBluetoothIcon } from "../Service"
import BluetoothDevice from "./BluetoothDevice"

export default function BluetoothWidget() {
    return (
        <box
            className="bluetooth-widget"
            orientation={Gtk.Orientation.VERTICAL}
            spacing={4}
        >
            <eventbox
                className="bluetooth-header"
                onButtonPressEvent={() => toggleExpanded()}
            >
                <box spacing={8} halign={Gtk.Align.FILL}>
                    <box spacing={6}>
                        <icon
                            icon={bind(bluetoothEnabled).as(() => getBluetoothIcon())}
                            className={bind(bluetoothEnabled).as(enabled =>
                                `bluetooth-icon ${enabled ? 'enabled' : 'disabled'}`
                            )}
                        />
                        <box
                            heightRequest={8}
                            widthRequest={8}
                            valign={Gtk.Align.CENTER}
                            className={bind(bluetoothEnabled).as(enabled =>
                                `bluetooth-status-dot ${enabled ? 'active' : 'inactive'}`
                            )}
                        />
                    </box>
                    <label
                        label="Bluetooth"
                        className="bluetooth-title"
                        halign={Gtk.Align.START}
                        hexpand={true}
                    />
                    <box className="bluetooth-controls" spacing={4}>
                        <button
                            className={bind(bluetoothEnabled).as(enabled =>
                                `bluetooth-toggle-btn ${enabled ? 'on' : 'off'}`
                            )}
                            on_clicked={() => toggleBluetooth()}
                        >
                            <label
                                label={bind(bluetoothEnabled).as(enabled => enabled ? "ON" : "OFF")}
                                className="bluetooth-toggle-label"
                            />
                        </button>
                        {bind(isExpanded).as(expanded => (
                            <button
                                className="bluetooth-expand-btn"
                                on_clicked={() => toggleExpanded()}
                            >
                                <icon icon={expanded ? "pan-up-symbolic" : "pan-down-symbolic"} />
                            </button>
                        ))}
                    </box>
                </box>
            </eventbox>

            {bind(isExpanded).as(expanded => (
                <box
                    className="bluetooth-expanded"
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={4}
                    visible={expanded}
                    heightRequest={100}
                    valign={Gtk.Align.CENTER}
                >
                    {bind(bluetoothEnabled).as(enabled => {
                        if (!enabled) {
                            // When Bluetooth is off, show clear message
                            return (
                                <label
                                    label="Bluetooth is off"
                                    className="bluetooth-disabled-message"
                                    halign={Gtk.Align.CENTER}
                                    valign={Gtk.Align.CENTER}
                                    hexpand={true}
                                    vexpand={true}
                                />
                            )
                        }

                        // When Bluetooth is on, show scan button and devices
                        return (
                            <box
                                orientation={Gtk.Orientation.VERTICAL}
                                spacing={4}
                            >
                                <button
                                    className="bluetooth-scan-button"
                                    on_clicked={toggleScan}
                                >
                                    <box spacing={6} halign={Gtk.Align.FILL}>
                                        <icon
                                            icon={bind(isScanning).as(scanning =>
                                                scanning ? "process-working-symbolic" : "view-refresh-symbolic"
                                            )}
                                            className={bind(isScanning).as(scanning =>
                                                `bluetooth-scan-icon ${scanning ? 'scanning' : ''}`
                                            )}
                                        />
                                        <label
                                            label={bind(isScanning).as(scanning =>
                                                scanning ? "Scanning..." : "Scan for devices"
                                            )}
                                            className="bluetooth-scan-label"
                                            halign={Gtk.Align.START}
                                            hexpand={true}
                                        />
                                    </box>
                                </button>

                                <box
                                    className="bluetooth-devices"
                                    orientation={Gtk.Orientation.VERTICAL}
                                    spacing={2}
                                >
                                    {bind(bluetoothDevices).as(devices => {
                                        if (!devices || devices.length === 0) {
                                            return (
                                                <label
                                                    label="No devices found"
                                                    className="bluetooth-empty"
                                                />
                                            )
                                        }

                                        // Show paired devices + discovered devices during scan
                                        const availableDevices = devices.filter((device: any) => {
                                            // Always show paired devices (main use case)
                                            if (device.paired) return true

                                            // Show discovered devices only when scanning
                                            if (device.connectable && isScanning.get()) return true

                                            return false
                                        })

                                        // Sort: connected first, then paired, then discoverable
                                        availableDevices.sort((a: any, b: any) => {
                                            if (a.connected && !b.connected) return -1
                                            if (!a.connected && b.connected) return 1
                                            if (a.paired && !b.paired) return -1
                                            if (!a.paired && b.paired) return 1
                                            return 0
                                        })

                                        if (availableDevices.length === 0) {
                                            return (
                                                <label
                                                    label="No paired devices"
                                                    className="bluetooth-empty"
                                                />
                                            )
                                        }

                                        return availableDevices.map((device: any) => (
                                            <BluetoothDevice device={device} />
                                        ))
                                    })}
                                </box>
                            </box>
                        )
                    })}
                </box>
            ))}
        </box>
    )
}