pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The single source of truth for "which player do the bar and the media keys
// act on". Both used to decide separately — the bar ranked players itself
// while the keys went through `playerctl --player=playerctld` — so the bar
// could show Spotify while a key press hit a paused YouTube tab instead.
//
// playerctld is not usable as that authority. It re-elects on any
// PropertiesChanged, so a browser that merely churns metadata keeps stealing
// the head: with Spotify playing and a paused Zen tab idle, it stayed pinned
// to the tab, and a play-pause key started the tab over the music.
Singleton {
    id: root

    readonly property int recentPlayingMax: 12
    property string explicitPlayerKey: ""
    property var recentPlayingKeys: []
    readonly property var activePlayers: Mpris.players.values.filter((candidate) => {
        return !isProxyPlayer(candidate) && candidate.playbackState !== MprisPlaybackState.Stopped && !isStalePaused(candidate);
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

    function hasTrackMetadata(candidate) {
        return [candidate?.trackTitle, candidate?.trackArtist].every(value => {
            const text = String(value ?? "").trim();
            return text.length > 0 && !/^(unknown(?: artist| title| track)?|n\/a)$/i.test(text);
        });
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
        if (!storedKey || !candidate)
            return false;

        const id = playerKey(candidate);
        if (storedKey === id)
            return true;

        const left = storedKey.toLowerCase();
        const right = id.toLowerCase();
        return left.includes(right) || right.includes(left);
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
        const active = activePlayers;
        const pruned = recentPlayingKeys.filter((storedKey) => {
            return active.some((candidate) => {
                return keysMatch(storedKey, candidate);
            });
        });
        if (pruned.length !== recentPlayingKeys.length)
            recentPlayingKeys = pruned;

        if (explicitPlayerKey.length > 0 && !active.some((candidate) => {
            return keysMatch(explicitPlayerKey, candidate);
        }))
            explicitPlayerKey = "";

        MediaPause.prune(Mpris.players.values.filter((candidate) => {
            return tracksPauseClock(candidate);
        }).map(playerKey));
    }

    // Something audible outranks everything silent: a key press must never
    // start a second stream over what is already playing. Only within that
    // group does recency, and then an explicit pick, decide.
    function pickActivePlayer() {
        const active = activePlayers;
        if (!active.length)
            return null;

        const playing = active.filter((candidate) => {
            return candidate.isPlaying;
        });
        if (playing.length > 0) {
            if (explicitPlayerKey.length > 0) {
                const explicitHit = playing.find((candidate) => {
                    return keysMatch(explicitPlayerKey, candidate);
                });
                if (explicitHit)
                    return explicitHit;

            }
            return pickByStackOrder(playing);
        }
        if (explicitPlayerKey.length > 0) {
            const explicitHit = active.find((candidate) => {
                return keysMatch(explicitPlayerKey, candidate);
            });
            if (explicitHit)
                return explicitHit;

        }
        return pickByStackOrder(active);
    }

    // A player starting playback is the freshest statement of intent there is,
    // so it also clears an older pin: otherwise a player picked while
    // everything was paused would keep the media keys for good, which is the
    // same staleness that made playerctld unusable.
    function notePlayerPlaying(candidate) {
        if (!candidate || !candidate.isPlaying)
            return ;

        if (explicitPlayerKey.length > 0 && !keysMatch(explicitPlayerKey, candidate))
            explicitPlayerKey = "";

        pushRecentPlaying(candidate);
    }

    // Acting on a player is the strongest statement of intent there is, so it
    // pins the choice until that player goes away.
    function markPlayerInteracted() {
        if (!player)
            return ;

        pushRecentPlaying(player);
        explicitPlayerKey = playerKey(player);
    }

    function previous() {
        markPlayerInteracted();
        if (player && player.canGoPrevious)
            player.previous();

    }

    function togglePlayback() {
        if (!player)
            return ;

        markPlayerInteracted();
        if (player.isPlaying) {
            if (player.canPause)
                player.pause();

        } else if (player.canPlay) {
            player.play();
        }
    }

    function next() {
        markPlayerInteracted();
        if (player && player.canGoNext)
            player.next();

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
        onObjectAdded: root.prunePlayerState()
        onObjectRemoved: root.prunePlayerState()

        delegate: Connections {
            required property var modelData

            Component.onCompleted: {
                root.notePlayerPlaying(modelData);
                root.seedPlayerActivity(modelData);
            }

            // isPlaying is derived from playbackState, so this fires for every
            // transition an onIsPlayingChanged would have caught as well.
            function onPlaybackStateChanged() {
                if (modelData.isPlaying)
                    root.notePlayerPlaying(modelData);

                root.markPlayerActivity(modelData);
            }

            function onTrackTitleChanged() {
                root.markPlayerActivity(modelData);
            }

            target: modelData
        }

    }

}
