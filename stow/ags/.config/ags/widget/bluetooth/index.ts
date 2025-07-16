export { default as BluetoothWidget } from "./components/BluetoothWidget"
export { default as BluetoothDevice } from "./components/BluetoothDevice"
export { 
    bluetoothDevices, 
    bluetoothEnabled, 
    connectingDevices,
    isScanning,
    isExpanded,
    toggleBluetooth, 
    connectDevice, 
    toggleScan,
    toggleExpanded,
    isDeviceConnecting,
    getBluetoothIcon 
} from "./Service"