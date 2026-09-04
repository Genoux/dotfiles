pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    readonly property string statePath: `${ShellActions.stateDir}/media-pause.json`
    // Browsers register MPRIS per process, not per tab: closing the tab leaves the
    // player on the bus as Paused, holding the last track until the browser quits.
    // Nothing it reports separates that corpse from a real pause — it still claims
    // CanPlay and CanControl — so idle time is the only signal left. The clock
    // lives on disk because a config reload would otherwise hand every ghost a
    // fresh grace period, which also makes the widget impossible to verify.
    readonly property int graceMs: 10 * 60 * 1000
    property var entries: ({})
    property bool hydrated: false
    property bool bootReady: false
    property bool stateReady: false
    property string bootId: ""
    property double clockTick: Date.now()

    // Fires after the merge, not on `hydrated`: that flag flips first, so a
    // consumer watching it would prune the map the disk state has yet to land in.
    signal hydrationCompleted()

    // Seeding runs before the file finishes loading, so writes stay in memory until
    // hydration; otherwise startup would overwrite the very clock it needs to read.
    function persist(next) {
        entries = next;
        scheduleExpiry();
        if (!hydrated || !stateFile.adapter)
            return ;

        stateFile.adapter.pausedSince = JSON.stringify(next);
        stateFile.adapter.boot = bootId;
        stateFile.writeAdapter();
    }

    // isStale reads clockTick, so every binding that consults it re-evaluates on
    // each tick. A periodic clock would rebuild the whole bar on every beat for an
    // answer that changes once, so wake exactly when the soonest entry expires.
    function scheduleExpiry() {
        const now = Date.now();
        const pending = Object.keys(entries).map((key) => {
            return graceMs - (now - entries[key]);
        }).filter((remaining) => {
            return remaining > 0;
        });
        if (!pending.length) {
            expiryTimer.stop();
            return ;
        }
        expiryTimer.interval = Math.min.apply(null, pending);
        expiryTimer.restart();
    }

    // Disk holds the pause clock from before this process existed, so on the one
    // hydration pass it wins over the timestamps startup just seeded — otherwise
    // every restart would hand each ghost a fresh grace period.
    //
    // Only within one boot, though. A clock is a claim about uninterrupted bus
    // presence, and players with a stable dbusName (spotify, mpd, vlc) reuse their
    // key across logins: a name paused and quit last boot leaves an entry no
    // objectRemoved ever prunes, so its relaunch would hydrate as instantly stale
    // and never reach the bar. A boot mismatch discards the whole map.
    function hydrate() {
        if (hydrated || !bootReady || !stateReady)
            return ;

        let stored = ({});
        const storedBoot = stateFile.adapter ? stateFile.adapter.boot : "";
        try {
            if (!bootId || !storedBoot || storedBoot === bootId)
                stored = JSON.parse(stateFile.adapter ? (stateFile.adapter.pausedSince || "{}") : "{}");

        } catch (error) {
        }
        hydrated = true;
        persist(Object.assign({}, entries, clampToNow(stored)));
        hydrationCompleted();
    }

    // A timestamp ahead of the clock (ntp correction, a hand-set clock, state
    // copied off another machine) makes scheduleExpiry arm past the grace window,
    // so isStale never fires and the ghost stays in the bar for good.
    function clampToNow(stored) {
        const now = Date.now();
        const clamped = ({});
        Object.keys(stored).forEach((key) => {
            clamped[key] = Math.min(Number(stored[key]) || now, now);
        });
        return clamped;
    }

    function isStale(key, isPlaying) {
        if (!key || isPlaying)
            return false;

        const since = entries[key];
        return since !== undefined && (clockTick - since) > graceMs;
    }

    // A player already paused when the shell starts keeps whatever clock it had, or
    // a ghost that outlived the last session would get a fresh grace period.
    function seedActivity(key, isPlaying) {
        if (!key || isPlaying || entries[key] !== undefined)
            return ;

        const next = Object.assign({}, entries);
        next[key] = Date.now();
        persist(next);
    }

    function noteActivity(key, isPlaying) {
        if (!key)
            return ;

        const next = Object.assign({}, entries);
        if (isPlaying) {
            if (next[key] === undefined)
                return ;

            delete next[key];
        } else {
            next[key] = Date.now();
        }
        persist(next);
    }

    function prune(liveKeys) {
        const next = Object.assign({}, entries);
        const dropped = Object.keys(next).filter((key) => {
            return liveKeys.indexOf(key) < 0;
        });
        if (dropped.length === 0)
            return ;

        dropped.forEach((key) => {
            delete next[key];
        });
        persist(next);
    }

    Timer {
        id: expiryTimer

        onTriggered: {
            root.clockTick = Date.now();
            root.scheduleExpiry();
        }
    }

    Process {
        command: ["mkdir", "-p", ShellActions.stateDir]
        running: true
    }

    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false
        preload: true
        onLoaded: {
            root.stateReady = true;
            root.hydrate();
        }
        onLoadFailed: {
            root.stateReady = true;
            root.hydrate();
        }

        JsonAdapter {
            property string pausedSince: "{}"
            property string boot: ""
        }

    }

    FileView {
        id: bootFile

        path: "/proc/sys/kernel/random/boot_id"
        printErrors: false
        preload: true
        onLoaded: {
            root.bootId = text().trim();
            root.bootReady = true;
            root.hydrate();
        }
        onLoadFailed: {
            root.bootReady = true;
            root.hydrate();
        }
    }

}
