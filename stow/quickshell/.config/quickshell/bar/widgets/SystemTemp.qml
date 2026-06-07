import qs
import qs.config
import qs.components
CommandPill {
    runCommand: ["bash", "-lc", "cpu=0; gpu=0; for name in /sys/class/hwmon/hwmon*/name; do [ -r \"$name\" ] || continue; label=$(cat \"$name\"); case \"$label\" in *k10temp*|*coretemp*|*cpu*) dir=${name%/name}; for temp in \"$dir\"/temp*_input; do [ -r \"$temp\" ] && cpu=$(( $(cat \"$temp\") / 1000 )) && break; done; break;; esac; done; for temp in /sys/class/drm/card*/device/hwmon/hwmon*/temp1_input; do [ -r \"$temp\" ] && gpu=$(( $(cat \"$temp\") / 1000 )) && break; done; [ \"$gpu\" -eq 0 ] && command -v nvidia-smi >/dev/null 2>&1 && gpu=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1); if [ \"$cpu\" -gt 0 ] && [ \"$gpu\" -gt 0 ]; then avg=$(( (cpu + gpu) / 2 )); else avg=$(( cpu > gpu ? cpu : gpu )); fi; printf '󰔏 %s°C' \"$avg\""]
    clickCommand: ["bash", "-lc", "hyprctl dispatch 'function() require(\"actions.launchers\").launchOrFocus(\"btop\", \"btop\", \"htop\") end'"]
    interval: 30000
    foreground: Colors.base05
    fontFamily: Style.fontIcon
    horizontalPadding: 6
}
