declare const SRC: string;

// Console API, TextDecoder/TextEncoder for GJS/AGS environment
declare global {
  var console: {
    log(...args: any[]): void;
    error(...args: any[]): void;
    warn(...args: any[]): void;
    info(...args: any[]): void;
    debug(...args: any[]): void;
  };

  var TextDecoder: {
    new (encoding?: string): {
      decode(input?: ArrayBuffer | ArrayBufferView): string;
    };
  };

  var TextEncoder: {
    new (): {
      encode(input?: string): Uint8Array;
    };
  };
}

// GObject Introspection modules (gi://)
declare module "gi://AstalHyprland" {
  const Hyprland: any;
  export default Hyprland;
}

declare module "gi://AstalBattery" {
  const Battery: any;
  export default Battery;
}

declare module "gi://AstalBluetooth" {
  const Bluetooth: any;
  export default Bluetooth;
}

declare module "gi://AstalMpris" {
  const Mpris: any;
  export default Mpris;
}

declare module "gi://AstalNetwork" {
  const Network: any;
  export default Network;
}

declare module "gi://AstalApps" {
  const Apps: any;
  export default Apps;
}

declare module "gi://AstalTray" {
  const Tray: any;
  export default Tray;
}

declare module "gi://AstalWp" {
  const Wp: any;
  export default Wp;
}

declare module "gi://GLib" {
  const GLib: any;
  export default GLib;
}

declare module "gi://Gio" {
  const Gio: any;
  export default Gio;
}

declare module "inline:*" {
  const content: string;
  export default content;
}

declare module "*.scss" {
  const content: string;
  export default content;
}

declare module "*.blp" {
  const content: string;
  export default content;
}

declare module "*.css" {
  const content: string;
  export default content;
}

export {};
