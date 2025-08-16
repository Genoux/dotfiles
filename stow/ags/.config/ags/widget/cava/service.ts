import { createState } from "ags";
import { subprocess } from "ags/process";
import GLib from "gi://GLib";

const CFG = "widget/cava/config/config";
let BAR_COUNT = 8;

try {
  // GLib.file_get_contents returns [success, data (bytes)]
  const [_success, data] = GLib.file_get_contents(CFG);
  // decode to string
  const text = new TextDecoder().decode(data);
  // Now you can use .match
  const match = text.match(/^\s*bars\s*=\s*(\d+)/m);
  if (match) {
    BAR_COUNT = parseInt(match[1], 10);
  }
} catch (e) {
  print(`Could not read cava config, using default BAR_COUNT: ${e}`);
}

export const [barsAccessor, setBars] = createState<number[]>(
  Array(BAR_COUNT).fill(0)
);

const norm = (v: number) => Math.round(2 + (Math.min(v, 1000) / 1000) * 14);

subprocess(
  ["cava", "-p", CFG],
  (out) => {
    const nums = out
      .trim()
      .split(";")
      .map(Number)
      .filter((n) => !isNaN(n));
    if (nums.length >= BAR_COUNT) setBars(nums.slice(0, BAR_COUNT).map(norm));
  },
  (err) => console.error("cava crash:", err)
);

export { BAR_COUNT };
