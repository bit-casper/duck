pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Duck's settings, backed by ~/.config/duck/config.json.
//
// The file is the single source of truth: the `duck` CLI writes it directly and
// the settings window writes it through set(). watchChanges picks up either one,
// so both paths stay in sync without talking to each other.
Singleton {
    id: root

    readonly property string configDir: Quickshell.env("HOME") + "/.config/duck"
    readonly property string path: configDir + "/config.json"

    readonly property var defaults: ({
        "apps": [],
        "showRunning": true,
        "bordered": true,
        "pushWindows": false,
        "iconSize": 44,
        "padding": 8,
        "gap": 10,
        "revealDelay": 90,
        "hideDelay": 350,
        "edgeReveal": true,
        "animate": true
    })

    property var values: defaults

    // Typed accessors so the rest of the shell never deals with missing keys.
    readonly property var apps: values.apps !== undefined ? values.apps : defaults.apps
    readonly property bool showRunning: values.showRunning !== undefined ? values.showRunning : defaults.showRunning
    readonly property bool bordered: values.bordered !== undefined ? values.bordered : defaults.bordered
    readonly property bool pushWindows: values.pushWindows !== undefined ? values.pushWindows : defaults.pushWindows
    readonly property int iconSize: values.iconSize !== undefined ? values.iconSize : defaults.iconSize
    readonly property int padding: values.padding !== undefined ? values.padding : defaults.padding
    readonly property int gap: values.gap !== undefined ? values.gap : defaults.gap
    readonly property int revealDelay: values.revealDelay !== undefined ? values.revealDelay : defaults.revealDelay
    readonly property int hideDelay: values.hideDelay !== undefined ? values.hideDelay : defaults.hideDelay
    readonly property bool edgeReveal: values.edgeReveal !== undefined ? values.edgeReveal : defaults.edgeReveal
    readonly property bool animate: values.animate !== undefined ? values.animate : defaults.animate

    signal changed()

    function clone(o) {
        return JSON.parse(JSON.stringify(o));
    }

    function set(key, value) {
        const next = clone(root.values);
        next[key] = value;
        root.values = next;
        write();
    }

    function setApps(list) {
        set("apps", list);
    }

    function write() {
        file.setText(JSON.stringify(root.values, null, 2) + "\n");
    }

    function parse(text) {
        let parsed = {};
        try {
            parsed = JSON.parse(text);
            if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) parsed = {};
        } catch (e) {
            // A half-written or hand-mangled file should never take the dock down;
            // fall back to defaults and leave the file alone for the user to fix.
            console.warn("duck: config.json is not valid JSON, using defaults:", e);
            parsed = {};
        }

        const merged = clone(root.defaults);
        for (const key in parsed) merged[key] = parsed[key];
        if (!Array.isArray(merged.apps)) merged.apps = [];

        root.values = merged;
        root.changed();
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        preload: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.parse(text())
        onLoadFailed: function (error) {
            // Usually just means the file does not exist yet. Run on defaults
            // rather than writing one back: writing from inside a load callback
            // can ping-pong with the file watcher that the write itself trips.
            // The installer and the `duck` CLI both create the file.
            root.values = root.clone(root.defaults);
            root.changed();
        }
    }
}
