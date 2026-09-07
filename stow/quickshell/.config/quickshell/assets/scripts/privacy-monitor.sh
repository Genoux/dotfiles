#!/usr/bin/env bash
# Polls webcam, microphone, screen access, and local recording state.
# Emits "webcam:mic:screenAccess:recording<TAB>webcamSrc<TAB>micSrc<TAB>screenSrc" on change.

SCREEN_RECORDER_PATTERN="wl-screenrec|wf-recorder"

has_pactl=0
command -v pactl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && has_pactl=1
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
    jq -nr --argjson outputs "${1:-[]}" --argjson sources "${2:-[]}" '
        [$sources[] | select((.monitor_source // "") == "")
         | select((.monitor_of_sink // 4294967295) == 4294967295)
         | select((.properties["device.class"] // "") != "monitor")
         | select((.name // "") | endswith(".monitor") | not)
         | .index] as $microphones |
        [$outputs[] | select(.corked != true)
         | select(.source as $source | $microphones | index($source) != null)
         | .properties["application.name"] // .properties["application.process.binary"] // "Microphone"]
        | unique | join(",")
    ' 2>/dev/null
}

running_recorders() {
    pgrep -x -l "$SCREEN_RECORDER_PATTERN" 2>/dev/null |
        awk '{ print $2 }' | sort -u | paste -sd ','
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

build_payload() {
    local webcam_pids source_outputs sources pw_state recorders
    local webcam mic screen_access recording
    local webcam_src mic_src screen_src

    webcam_pids=$(get_webcam_pids)
    [ -n "$webcam_pids" ] && webcam=1 || webcam=0

    source_outputs="[]"
    sources="[]"
    if [ "$has_pactl" = "1" ]; then
        source_outputs=$(pactl -f json list source-outputs 2>/dev/null)
        sources=$(pactl -f json list sources 2>/dev/null)
    fi
    mic_src=$(mic_sources_from_outputs "$source_outputs" "$sources")
    [ -n "$mic_src" ] && mic=1 || mic=0

    pw_state=""
    [ "$has_pipewire" = "1" ] && pw_state=$(pw-dump 2>/dev/null)

    recorders=$(running_recorders)
    [ -n "$recorders" ] && recording=1 || recording=0
    if [ "$recording" = "1" ] || portal_screencast_active "$pw_state"; then
        screen_access=1
    else
        screen_access=0
    fi

    webcam_src=$(webcam_sources_from_pids "$webcam_pids" | prettify_sources)
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
