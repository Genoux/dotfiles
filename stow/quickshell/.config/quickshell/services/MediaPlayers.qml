pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property int recentPlayingMax: 12
    // A track longer than this is a live stream. They report a length near the
    // integer limit.
    readonly property int liveStreamSeconds: 86400
    property var recentPlayingKeys: []
    // The reader's explicit choice. It outranks everything until another player
    // starts playing or this one goes away; set from handlers, never from the
    // binding that reads it.
    property string pinnedPlayerKey: ""
    readonly property var activePlayers: Mpris.players.values.filter((candidate) => {
        return isAvailablePlayer(candidate) && !isStalePaused(candidate);
    })
    readonly property var player: pickActivePlayer()
    readonly property bool canGoPrevious: player ? player.canGoPrevious : false
    readonly property bool canGoNext: player ? player.canGoNext : false
    readonly property bool canTogglePlayback: player ? (player.isPlaying ? player.canPause : player.canPlay) : false

    // playerctld is a proxy, not a player: it re-exports whichever real player
    // it currently favours under its own bus name, so every player it can
    // offer is already on this list directly and it only ever contributes a
    // duplicate — one that outlives its source, keeping the final track and
    // isPlaying state after the last real player quits.
    function isProxyPlayer(candidate) {
        return String(candidate?.dbusName ?? "").endsWith(".playerctld");
    }

    function isAvailablePlayer(candidate) {
        if (!candidate || isProxyPlayer(candidate)
                || candidate.playbackState === MprisPlaybackState.Stopped)
            return false;

        return candidate.isPlaying || (candidate.canControl && candidate.canPlay);
    }

    function cleanField(value) {
        const text = String(value ?? "").trim();
        return /^(unknown(?: artist| title| track)?|n\/a)$/i.test(text) ? "" : text;
    }

    // Browsers report no artwork for a video, but the tab's address names it.
    // mqdefault is the clean 16:9 frame: hqdefault carries letterbox bars that
    // a square crop would keep.
    function artUrl(candidate) {
        const reported = String(candidate?.trackArtUrl ?? "");
        if (reported.length > 0)
            return reported;

        const address = String(candidate?.metadata?.["xesam:url"] ?? "");
        const video = address.match(/(?:youtube\.com\/(?:watch\?(?:[^#]*&)?v=|shorts\/|embed\/|live\/)|youtu\.be\/)([\w-]{11})/);
        return video ? `https://i.ytimg.com/vi/${video[1]}/mqdefault.jpg` : "";
    }

    function trackLabel(candidate) {
        return [candidate?.trackTitle, candidate?.trackArtist].map(cleanField).filter(text => text.length > 0).join(" - ");
    }

    // A title is enough: podcasts and episodes carry no artist, and requiring
    // one made a playing Spotify episode and a browser tab equally "without
    // metadata", leaving the choice between them to whichever played last.
    function hasTrackMetadata(candidate) {
        return cleanField(candidate?.trackTitle).length > 0;
    }

    // A camera feed or radio has no end to seek to, so it is not a track. It
    // never wins on its own; the switcher can still choose it.
    function isLiveStream(candidate) {
        return !!candidate?.lengthSupported && candidate.length >= liveStreamSeconds;
    }

    function isStalePaused(candidate) {
        if (!candidate)
            return false;

        return MediaPause.isStale(playerKey(candidate), candidate.isPlaying);
    }

    function playerKey(candidate) {
        if (!candidate)
            return "";

        if (candidate.dbusName)
            return candidate.dbusName;

        return candidate.desktopEntry || candidate.identity || "";
    }

    // activePlayers drops the proxy before staleness is ever consulted, so a
    // pause clock kept for it is written, persisted, and pruned without being
    // read once.
    function tracksPauseClock(candidate) {
        return !!candidate && !isProxyPlayer(candidate);
    }

    function seedPlayerActivity(candidate) {
        if (tracksPauseClock(candidate))
            MediaPause.seedActivity(playerKey(candidate), candidate.isPlaying);

    }

    function markPlayerActivity(candidate) {
        if (tracksPauseClock(candidate))
            MediaPause.noteActivity(playerKey(candidate), candidate.isPlaying);

    }

    function keysMatch(storedKey, candidate) {
        return !!storedKey && storedKey === playerKey(candidate);
    }

    // Only a playback-state transition or a deliberate user command reorders
    // the stack. Ranking on metadata instead is what wedges playerctld: an
    // idle tab that keeps rewriting its title would ride the head forever.
    function pushRecentPlaying(candidate) {
        const key = playerKey(candidate);
        if (!key)
            return ;

        const rest = recentPlayingKeys.filter((storedKey) => {
            return !keysMatch(storedKey, candidate);
        });
        recentPlayingKeys = [key].concat(rest).slice(0, recentPlayingMax);
    }

    function stackRank(candidate) {
        for (let i = 0; i < recentPlayingKeys.length; i++) {
            if (keysMatch(recentPlayingKeys[i], candidate))
                return i;

        }
        return recentPlayingMax + 1;
    }

    function pickByStackOrder(candidates) {
        if (!candidates.length)
            return null;

        return candidates.slice().sort((left, right) => {
            return stackRank(left) - stackRank(right);
        })[0];
    }

    function prunePlayerState() {
        const active = Mpris.players.values.filter(candidate => !isProxyPlayer(candidate));
        const pruned = recentPlayingKeys.filter((storedKey) => {
            return active.some((candidate) => {
                return keysMatch(storedKey, candidate);
            });
        });
        if (pruned.length !== recentPlayingKeys.length)
            recentPlayingKeys = pruned;

        if (!active.some(candidate => keysMatch(pinnedPlayerKey, candidate)))
            pinnedPlayerKey = "";

        MediaPause.prune(Mpris.players.values.filter((candidate) => {
            return tracksPauseClock(candidate);
        }).map(playerKey));
    }

    function pickActivePlayer() {
        const pinned = activePlayers.find(candidate => keysMatch(pinnedPlayerKey, candidate));
        if (pinned)
            return pinned;

        const tracks = activePlayers.filter(candidate => !isLiveStream(candidate));
        const playing = tracks.filter(candidate => candidate.isPlaying);
        const displayable = playing.filter(hasTrackMetadata);
        if (displayable.length)
            return pickByStackOrder(displayable);
        const paused = tracks.filter(hasTrackMetadata);
        if (paused.length)
            return pickByStackOrder(paused);
        if (playing.length)
            return pickByStackOrder(playing);
        return pickByStackOrder(tracks);
    }

    function selectPlayer(candidate) {
        if (!candidate || isProxyPlayer(candidate))
            return;

        pinnedPlayerKey = playerKey(candidate);
        markPlayerInteracted(candidate);
    }

    function notePlayerPlaying(candidate) {
        if (!candidate?.isPlaying || isProxyPlayer(candidate))
            return;

        if (!keysMatch(pinnedPlayerKey, candidate))
            pinnedPlayerKey = "";
        pushRecentPlaying(candidate);
    }

    function markPlayerInteracted(candidate = player) {
        if (!candidate || isProxyPlayer(candidate))
            return;

        pushRecentPlaying(candidate);
        markPlayerActivity(candidate);
    }

    function previous(target = player) {
        if (!target?.canGoPrevious)
            return;

        markPlayerInteracted(target);
        target.previous();
    }

    function togglePlayback(target = player) {
        if (!target || !(target.isPlaying ? target.canPause : target.canPlay))
            return;

        markPlayerInteracted(target);
        if (target.isPlaying)
            target.pause();
        else
            target.play();
    }

    function next(target = player) {
        if (!target?.canGoNext)
            return;

        markPlayerInteracted(target);
        target.next();
    }

    // Disk state lands after the players are already instantiated, so the
    // prune driven by onObjectAdded sees an empty map and keeps every dead key
    // the last session left behind.
    Connections {
        function onHydrationCompleted() {
            root.prunePlayerState();
        }

        target: MediaPause
    }

    Instantiator {
        model: Mpris.players.values
        onObjectAdded: Qt.callLater(root.prunePlayerState)
        onObjectRemoved: Qt.callLater(root.prunePlayerState)

        delegate: Connections {
            required property var modelData

            Component.onCompleted: {
                root.notePlayerPlaying(modelData);
                root.seedPlayerActivity(modelData);
            }

            function onIsPlayingChanged() {
                root.notePlayerPlaying(modelData);
                root.markPlayerActivity(modelData);
            }

            target: modelData
        }

    }

}
