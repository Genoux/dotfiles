#!/usr/bin/env bash
# Polls webcam, microphone, screen access, and local recording state.
# Emits "webcam:mic:screenAccess:recording<TAB>webcamSrc<TAB>micSrc<TAB>screenSrc" on change.

# Recorders whose presence means "actively writing a recording".
EXTERNAL_RECORDERS=(obs gpu-screen-recorder kooha)
# Superset also reported as a screen source, without implying a local recording.
SCREEN_RECORDERS=(wl-screenrec wf-recorder "${EXTERNAL_RECORDERS[@]}")
SCREEN_RECORDER_PATTERN=$(IFS='|'; printf '%s' "${SCREEN_RECORDERS[*]}")

has_pactl=0
command -v pactl >/dev/null 2>&1 && has_pactl=1
has_pipewire=0
command -v pw-dump >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && has_pipewire=1

join_sources() {
    printf '%s' "$1" | tr ' ' '\n' | sed '/^$/d' | sort -u | paste -sd ','
}

prettify_sources() {
    tr ',' '\n' | sed 's/-bin$//' | sed '/^$/d' | sort -u | paste -sd ','
}

# fuser re-walks every process's whole fd table (~0.27s with ~900 procs); a
# targeted symlink match is ~4x cheaper and yields the pids in the same pass.
get_webcam_pids() {
    find /proc/[0-9]*/fd -lname '/dev/video*' -printf '%h\n' 2>/dev/null |
        sed 's#^/proc/##; s#/fd$##' | sort -u
}

webcam_sources_from_pids() {
    local pid name apps=""

    while read -r pid; do
        [ -n "$pid" ] || continue
        read -r name < "/proc/$pid/comm" 2>/dev/null || continue
        [ -n "$name" ] && apps="${apps}${apps:+,}${name}"
    done <<<"$1"

    join_sources "$apps"
}

mic_sources_from_outputs() {
    printf '%s\n' "$1" | awk '
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

# One pgrep over /proc, not one per name: five separate -x calls cost ~0.19s
# here versus ~0.04s for a single alternation pattern.
running_recorders() {
    pgrep -x -l "$SCREEN_RECORDER_PATTERN" 2>/dev/null |
        awk '{ print $2 }' | sort -u | paste -sd ','
}

is_external_recorder() {
    local app
    for app in "${EXTERNAL_RECORDERS[@]}"; do
        case ",$1," in
            *",$app,"*) return 0 ;;
        esac
    done
    return 1
}

portal_screencast_active() {
    [ -n "$1" ] || return 1
    printf '%s' "$1" | jq -e '
        [.[] | select(.info?.props?)
         | select((.info.props["media.name"]? // "")
           | test("^(xdph-streaming|gsr-default|game capture)"))]
        | length > 0
    ' >/dev/null 2>&1
}

portal_screencast_sources() {
    [ -n "$1" ] || return 0
    printf '%s' "$1" | jq -r '
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
    ' 2>/dev/null
}

# A webcam that also registers as an audio source counts as an active mic.
webcam_is_mic() {
    [ "$1" = "1" ] && [ "$has_pactl" = "1" ] || return 1
    pactl list sources short 2>/dev/null | grep -qi "webcam\|camera\|video"
}

build_payload() {
    local webcam_pids source_outputs pw_state recorders
    local webcam mic screen_access recording
    local webcam_src mic_src screen_src

    webcam_pids=$(get_webcam_pids)
    [ -n "$webcam_pids" ] && webcam=1 || webcam=0

    source_outputs=""
    [ "$has_pactl" = "1" ] && source_outputs=$(pactl list source-outputs 2>/dev/null)
    if printf '%s' "$source_outputs" | grep -q 'target.object = "alsa_input'; then
        mic=1
    elif webcam_is_mic "$webcam"; then
        mic=1
    else
        mic=0
    fi

    pw_state=""
    [ "$has_pipewire" = "1" ] && pw_state=$(pw-dump 2>/dev/null)

    recorders=$(running_recorders)
    is_external_recorder "$recorders" && recording=1 || recording=0
    if [ "$recording" = "1" ] || portal_screencast_active "$pw_state"; then
        screen_access=1
    else
        screen_access=0
    fi

    webcam_src=$(webcam_sources_from_pids "$webcam_pids" | prettify_sources)
    mic_src=$(mic_sources_from_outputs "$source_outputs")
    screen_src=$(join_sources "$recorders,$(portal_screencast_sources "$pw_state")" | prettify_sources)

    printf '%s:%s:%s:%s\t%s\t%s\t%s' \
        "$webcam" "$mic" "$screen_access" "$recording" \
        "$webcam_src" "$mic_src" "$screen_src"
}

if [ "$1" = "--self-check" ]; then
    payload=$(build_payload)
    state=${payload%%$'\t'*}
    [ "$(printf '%s' "$payload" | awk -F'\t' '{print NF}')" = "4" ] ||
        { echo "FAIL: expected 4 tab-separated fields, got: $payload" >&2; exit 1; }
    [ "$(printf '%s' "$state" | awk -F: '{print NF}')" = "4" ] ||
        { echo "FAIL: expected 4 state flags, got: $state" >&2; exit 1; }
    printf '%s' "$state" | grep -Eq '^[01]:[01]:[01]:[01]$' ||
        { echo "FAIL: state flags must be 0 or 1, got: $state" >&2; exit 1; }
    echo "OK: $payload"
    exit 0
fi

# QuickShell does not reap its children when it exits, and this script only
# writes on change — so a static privacy state never trips SIGPIPE and the
# script would poll forever as an orphan. $PPID is cached at startup, so the
# live parent has to come from /proc.
launch_ppid=$PPID

orphaned() {
    local stat ppid
    read -r stat < /proc/self/stat || return 1
    ppid=${stat##*") "}     # comm may contain spaces; skip past its closing paren
    ppid=${ppid#* }         # drop the state field
    [ "${ppid%% *}" != "$launch_ppid" ]
}

last_state=""
while true; do
    orphaned && exit 0

    payload=$(build_payload)

    if [ "$payload" != "$last_state" ]; then
        printf '%s\n' "$payload"
        last_state="$payload"
    fi

    sleep 1
done
