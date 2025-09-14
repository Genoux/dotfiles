-- Auto-switch to Bluetooth audio devices when connected
bluetooth_auto_switch = {}

function bluetooth_auto_switch.on_device_added(device)
  local device_name = device.properties["device.name"]
  local device_bus = device.properties["device.bus"]
  local device_class = device.properties["device.class"]
  
  -- Check if it's a Bluetooth audio device
  if device_bus == "bluetooth" and device_class == "Audio/Sink" then
    -- Set as default sink when connected
    WpCore.call("set-default", "Audio/Sink", device_name)
    print("Auto-switched to Bluetooth audio device: " .. device_name)
  end
end

-- Monitor for new devices
device_monitor = WpObjectManager:new()
device_monitor:add_interest(WpDevice, nil)
device_monitor:request_object_features(WpDevice, WpPipewireObject.features.minimal)

device_monitor:connect("object-added", function (mgr, device)
  bluetooth_auto_switch.on_device_added(device)
end)

device_monitor:activate()