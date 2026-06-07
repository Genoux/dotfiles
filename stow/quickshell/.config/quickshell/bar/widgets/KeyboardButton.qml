import qs
import qs.config
import qs.components

CommandPill {
    text: "EN"
    runCommand: ["bash", "-lc", "hyprctl devices -j 2>/dev/null | python -c 'import json,sys; data=json.load(sys.stdin); kb=next((k for k in data.get(\"keyboards\", []) if k.get(\"main\")), {}); layout=kb.get(\"active_keymap\", \"\").lower(); print(\"FR\" if \"french\" in layout or \"canada\" in layout else \"EN\")'"]
    clickCommand: ["bash", "-lc", "keyboard=$(hyprctl devices -j | python -c 'import json,sys; data=json.load(sys.stdin); kb=next((k for k in data.get(\"keyboards\", []) if k.get(\"main\")), None); print(kb.get(\"name\", \"\") if kb else \"\")'); [ -n \"$keyboard\" ] && hyprctl switchxkblayout \"$keyboard\" next"]
    interval: 2000
    formatOutput: (output) => output.trim() || "EN"
    foreground: Colors.base05
    fontFamily: Style.fontSans
    fontSize: Style.fontSizeXs
    horizontalPadding: 8
    minimumWidth: 30
}
