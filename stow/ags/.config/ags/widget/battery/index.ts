import { bind } from "astal"
import { battery } from "./Service"

export { default as BatteryDisplay } from "./components/BatteryDisplay";
export { battery, getBatteryIcon, getBatteryLevel } from "./Service";

// Export battery visibility for use in Bar sections
export const batteryVisible = bind(battery, "devices").as((devices: any[]) => 
    Array.isArray(devices) && devices.some((device: any) => device && device.device_type === 2)
); 