import { createState } from "ags";
import { subprocess } from "ags/process";
import GLib from "gi://GLib";

const CFG = "widget/cava/config/config";
let BAR_COUNT = 4;

try {
  const [_success, data] = GLib.file_get_contents(CFG);
  const text = new TextDecoder().decode(data);
  const match = text.match(/^\s*bars\s*=\s*(\d+)/m);
  if (match) {
    BAR_COUNT = parseInt(match[1], 10);
  }
} catch (e) {
  print(`Could not read cava config, using default BAR_COUNT: ${e}`);
}

export const [barsAccessor, setBars] = createState<number[]>(Array(BAR_COUNT).fill(0));

const norm = (v: number) => Math.round(2 + (Math.min(v, 1000) / 1000) * 10);

let updateTimeout: number | null = null;

// Start cava subprocess - systemd service sets TERM=dumb to prevent terminal errors
subprocess(
  ["cava", "-p", CFG],
  (out) => {
    if (updateTimeout) return;

    const nums = out
      .trim()
      .split(";")
      .map(Number)
      .filter((n) => !isNaN(n));

    if (nums.length >= BAR_COUNT) {
      setBars(nums.slice(0, BAR_COUNT).map(norm));

      updateTimeout = setTimeout(() => {
        updateTimeout = null;
      }, 16) as any;
    }
  },
  (err) => console.error("cava error:", err)
);
