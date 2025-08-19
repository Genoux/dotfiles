-- Set Bluetooth audio devices as higher priority than USB/built-in audio
bluetooth_policy = {}

function bluetooth_policy.on_device_ready(device)
  local device_name = device.properties["device.name"]
  local device_class = device.properties["device.class"]
  local device_bus = device.properties["device.bus"]
  
  -- Prioritize Bluetooth audio devices
  if device_bus == "bluetooth" then
    device:set_property("priority.driver", 1000)
    device:set_property("priority.session", 1000)
  end
end

device_monitor = WpObjectManager:new()
device_monitor:add_interest(WpDevice, nil)
device_monitor:request_object_features(WpDevice, WpPipewireObject.features.minimal)

device_monitor:connect("objects-changed", function (mgr)
  for device in mgr:iterate() do
    bluetooth_policy.on_device_ready(device)
  end
end)

device_monitor:activate()