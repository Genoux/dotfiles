import { subprocess } from "ags/process";
import { notify } from "./notification";

type UsbEvent = {
  action: "add" | "remove";
  label: string;
};

function handleUsbEvent(line: string): void {
  const trimmed = line.trim();
  if (!trimmed) return;

  const [action, ...labelParts] = trimmed.split("|");
  const label = labelParts.join("|").trim();
  if ((action !== "add" && action !== "remove") || !label) return;

  const event: UsbEvent = { action, label };

  if (event.action === "add") {
    notify({
      title: "USB connected",
      body: event.label,
      icon: "drive-removable-media-symbolic",
      timeout: 4000,
    });
    return;
  }

  notify({
    title: "USB disconnected",
    body: event.label,
    icon: "media-eject-symbolic",
    timeout: 4000,
  });
}

let usbMonitorProcess: unknown = null;

export function startUsbNotifications(): void {
  if (usbMonitorProcess) return;

  usbMonitorProcess = subprocess(
    [
      "bash",
      "-c",
      `
      udevadm monitor --udev --subsystem-match=usb | while read -r _ _ action devpath _rest; do
        [[ "$action" == "add" || "$action" == "remove" ]] || continue
        [[ "$devpath" == /* ]] || continue

        props=$(udevadm info -q property -p "$devpath" 2>/dev/null) || continue
        echo "$props" | grep -qx 'DEVTYPE=usb_device' || continue
        echo "$props" | grep -qx 'ID_USB_DRIVER=hub' && continue

        model=$(echo "$props" | awk -F= '
          /^ID_MODEL_FROM_DATABASE=/ { print substr($0, index($0, "=") + 1); exit }
          /^ID_MODEL=/ { model = substr($0, index($0, "=") + 1) }
          END { print model }
        ')
        vendor=$(echo "$props" | awk -F= '/^ID_VENDOR=/ { print substr($0, index($0, "=") + 1); exit }')

        if [[ -n "$model" ]]; then
          label="\${model//_/ }"
        elif [[ -n "$vendor" ]]; then
          label="\${vendor//_/ }"
        else
          label="USB device"
        fi

        printf '%s|%s\\n' "$action" "$label"
      done
    `,
    ],
    handleUsbEvent,
    (err) => {
      console.error("[USB] Monitor error:", err);
      usbMonitorProcess = null;
    },
  );
}
