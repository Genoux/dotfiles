import Bluetooth from "gi://AstalBluetooth";

export const bluetooth = Bluetooth.get_default();
import { createBinding } from "ags";

export const isBluetoothOn = createBinding(
    bluetooth as any,
    "is-powered"
  );
  