import { Gtk } from "astal/gtk3"
import { battery, getBatteryIcon, getBatteryLevel } from "../Service"
import { bind } from "astal"

// UI Component - Battery Display
export default function BatteryDisplay() {
    // Check if battery exists, return null if not (this will hide the entire section)
    const hasBattery = bind(battery, "devices").as((devices: any[]) => 
        Array.isArray(devices) && devices.some((device: any) => device && device.device_type === 2)
    );
    
    // Get battery device for data binding
    const batteryDevice = bind(battery, "devices").as((devices: any[]) => {
        if (!Array.isArray(devices)) return null;
        return devices.find((d: any) => d && d.device_type === 2) || null;
    });
    
    return (
        <button
            className="battery-display"
            halign={Gtk.Align.CENTER}
            visible={hasBattery}
            tooltip_text={bind(batteryDevice).as((device: any) => 
                device ? `Battery: ${Math.round((device.percentage || 0) * 100)}% (${device.state === 1 ? 'Charging' : device.state === 2 ? 'Discharging' : 'Full'})` : "No battery"
            )}
        >
            <box spacing={4}>
                <icon 
                    icon={bind(batteryDevice).as((device: any) => 
                        device ? getBatteryIcon((device.percentage || 0) * 100, device.state === 1) : "battery-missing-symbolic"
                    )}
                    className={bind(batteryDevice).as((device: any) => 
                        device ? `battery-icon battery-${getBatteryLevel((device.percentage || 0) * 100)}` : "battery-icon"
                    )}
                />
                <label 
                    label={bind(batteryDevice).as((device: any) => 
                        device ? `${Math.round((device.percentage || 0) * 100)}%` : ""
                    )}
                    className={bind(batteryDevice).as((device: any) => 
                        device ? `battery-label battery-${getBatteryLevel((device.percentage || 0) * 100)}` : "battery-label"
                    )}
                />
            </box>
        </button>
    )
} 