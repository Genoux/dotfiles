#!/usr/bin/env bash
# Polls webcam, microphone, screen access, and local recording state.
# Emits "webcam:mic:screenAccess:recording<TAB>webcamSrc<TAB>micSrc<TAB>screenSrc" on change.

join_sources() {
    printf '%s' "$1" | tr ' ' '\n' | sed '/^$/d' | sort -u | paste -sd ','
}

prettify_sources() {
    tr ',' '\n' | sed 's/-bin$//' | sed '/^$/d' | sort -u | paste -sd ','
}

get_webcam_sources() {
    local apps="" name pid

    for dev in /dev/video*; do
        [ -e "$dev" ] || continue
        while read -r pid; do
            [ -n "$pid" ] || continue
            name=$(ps -p "$pid" -o comm= 2>/dev/null || true)
            [ -n "$name" ] && apps="${apps}${apps:+,}${name}"
        done < <(fuser "$dev" 2>/dev/null | tr ' ' '\n')
    done

    join_sources "$apps"
}

get_mic_sources() {
    if ! command -v pactl >/dev/null 2>&1; then
        echo ""
        return
    fi

    pactl list source-outputs 2>/dev/null | awk '
        /Source Output #/ { block = "" }
        { block = block $0 "\n" }
        /^$/ {
            if (block ~ /target\.object = "alsa_input/ && block ~ /application\.name = "/) {
                match(block, /application\.name = "([^"]+)"/, parts)
                if (parts[1] != "") print parts[1]
            }
            block = ""
        }
        END {
            if (block ~ /target\.object = "alsa_input/ && block ~ /application\.name = "/) {
                match(block, /application\.name = "([^"]+)"/, parts)
                if (parts[1] != "") print parts[1]
            }
        }
    ' | sort -u | paste -sd ','
}

get_recorder_sources() {
    local apps=""

    for app in wl-screenrec wf-recorder obs gpu-screen-recorder kooha; do
        pgrep -x "$app" >/dev/null 2>&1 && apps="${apps}${apps:+,}${app}"
    done

    echo "$apps"
}

get_portal_screencast_sources() {
    if ! command -v pw-dump >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        echo ""
        return
    fi

    pw-dump 2>/dev/null | jq -r '
        ([.[] | select(.type=="PipeWire:Interface:Client")
          | {key: (.id|tostring), value: (.info.props["application.name"] // .info.props["application.process.binary"] // "")}
         ] | from_entries) as $clients |
        [.[] | select(.type=="PipeWire:Interface:Node")
         | select((.info.props["media.class"]? // "") == "Stream/Input/Video")
         | select((.info.state? // "") == "running")
         | select((.info.props["media.name"]? // "") | test("webrtc|consume|pipewirestream"))
         | ($clients[(.info.props["client.id"] | tostring)] // .info.props["node.name"] // empty)
         | select(. != "")
        ] | unique | join(",")
    '
}

get_screen_sources() {
    local recorders portal combined

    recorders=$(get_recorder_sources)
    portal=$(get_portal_screencast_sources)

    if [ -n "$recorders" ] && [ -n "$portal" ]; then
        combined="${recorders},${portal}"
    else
        combined="${recorders}${portal}"
    fi

    join_sources "$combined" | prettify_sources
}

check_webcam() {
    fuser /dev/video* 2>/dev/null | grep -q . && echo 1 || echo 0
}

check_mic() {
    if command -v pactl >/dev/null 2>&1; then
        pactl list source-outputs 2>/dev/null | grep -q 'target.object = "alsa_input' && echo 1 && return
    fi
    echo 0
}

check_webcam_mic() {
    local webcam_active="$1"
    if [ "$webcam_active" = "1" ] && command -v pactl >/dev/null 2>&1; then
        pactl list sources short 2>/dev/null | grep -qi "webcam\|camera\|video" && echo 1 && return
    fi
    echo 0
}

check_portal_screencast() {
    if ! command -v pw-dump >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        echo 0
        return
    fi

    pw-dump 2>/dev/null | jq -e '
        [.[] | select(.info?.props?)
         | select((.info.props["media.name"]? // "")
           | test("^(xdph-streaming|gsr-default|game capture)"))]
        | length > 0
    ' >/dev/null 2>&1 && echo 1 || echo 0
}

check_local_recording() {
    pgrep -x wl-screenrec >/dev/null 2>&1 && echo 1 && return
    pgrep -x wf-recorder >/dev/null 2>&1 && echo 1 && return
    pgrep -x obs >/dev/null 2>&1 && echo 1 && return
    pgrep -x gpu-screen-recorder >/dev/null 2>&1 && echo 1 && return
    pgrep -x kooha >/dev/null 2>&1 && echo 1 && return
    pgrep -f "^[^ ]*wl-screenrec" >/dev/null 2>&1 && echo 1 && return
    pgrep -f "^[^ ]*wf-recorder" >/dev/null 2>&1 && echo 1 && return
    echo 0
}

check_screen_access() {
    [ "$(check_local_recording)" = "1" ] && echo 1 && return
    check_portal_screencast
}

last_state=""
while true; do
    cur_webcam=$(check_webcam)
    cur_mic=$(check_mic)
    cur_webcam_mic=$(check_webcam_mic "$cur_webcam")
    cur_screen_access=$(check_screen_access)
    cur_recording=$(check_local_recording)

    if [ "$cur_mic" = "1" ] || [ "$cur_webcam_mic" = "1" ]; then
        final_mic=1
    else
        final_mic=0
    fi

    state="$cur_webcam:$final_mic:$cur_screen_access:$cur_recording"
    webcam_src=$(get_webcam_sources | prettify_sources)
    mic_src=$(get_mic_sources)
    screen_src=$(get_screen_sources)
    payload="${state}	${webcam_src}	${mic_src}	${screen_src}"

    if [ "$payload" != "$last_state" ]; then
        printf '%s\n' "$payload"
        last_state="$payload"
    fi

    sleep 1
done
