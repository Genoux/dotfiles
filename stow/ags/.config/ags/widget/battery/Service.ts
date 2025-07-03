import Battery from "gi://AstalBattery"

// Get the UPower instance directly - this is the correct way
let battery: any = null
try {
    battery = new Battery.UPower()
    console.log("Battery service initialized successfully")
} catch (error) {
    console.error("Failed to initialize UPower battery service:", error)
    // Create a fallback object with empty devices
    battery = {
        devices: [],
        get_devices: () => []
    }
}

// Export the battery instance for direct use
export { battery }

// Helper function to get battery level for styling
export function getBatteryLevel(percentage: number): 'critical' | 'low' | 'medium' | 'high' | 'full' {
    if (percentage <= 15) {
        return 'critical';
    } else if (percentage <= 30) {
        return 'low';
    } else if (percentage <= 60) {
        return 'medium';
    } else if (percentage < 100) {
        return 'high';
    } else {
        return 'full';
    }
}

// Helper function to get appropriate battery icon
export function getBatteryIcon(percentage: number, charging: boolean): string {
    if (charging) {
        return "battery-charging-symbolic";
    }
    
    // Battery level icons for discharging
    if (percentage <= 10) {
        return "battery-caution-symbolic";
    } else if (percentage <= 20) {
        return "battery-low-symbolic";
    } else if (percentage <= 50) {
        return "battery-good-symbolic";
    } else if (percentage < 100) {
        return "battery-full-symbolic";
    } else {
        return "battery-full-charged-symbolic";
    }
}

// Helper to check if any battery device is available (use directly in components instead) 