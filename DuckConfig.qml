import QtQuick
import Quickshell
import Quickshell.Io

// Duck's settings, backed by ~/.config/duck/config.json.
//
// An ordinary object rather than a QML singleton: Omarchy's plugins do not use
// singletons, and the shell loads this from the plugin directory where a
// singleton would need its own qmldir to be registered at all.
//
// The file is the source of truth: the `duck` CLI writes it directly and the
// settings window writes it through set(). A watcher picks up either.
//
// Writes and the watcher have to be kept from fighting each other. Saving trips
// the very watcher that reloads the file, and a reload already in flight can
// deliver pre-write content *after* the write lands — which reverts the value
// and is what made toggles snap back when flipped quickly. So writes are
// coalesced, and reloads are ignored while one is settling.
Item {
    id: root

    readonly property string configDir: Quickshell.env("HOME") + "/.config/duck"
    readonly property string path: configDir + "/config.json"

    readonly property var defaults: ({
        "apps": [],
        "showRunning": true,
        "bordered": true,
        "pushWindows": false,
        "edgeReveal": true,
        "revealDelay": 90,
        "hideDelay": 350,
        "animate": true,

        // Hyprland key strings, registered at runtime by DuckKeys. An empty
        // string leaves the action unbound; `moveprev` / `movenext` ship that
        // way because Super+Shift+Ctrl+arrows are a lot of modifier for
        // something dragging an icon already does.
        "keys": ({
            "toggle": "SUPER + CTRL + DOWN",
            "activate": "SUPER + CTRL + UP",
            "prev": "SUPER + CTRL + LEFT",
            "next": "SUPER + CTRL + RIGHT",
            "moveprev": "",
            "movenext": "",
            "hide": ""
        })
    })

    // Settings that used to exist and are now derived from the display scale.
    // They are dropped on the next write rather than silently honoured.
    readonly property var retired: ["iconSize", "padding", "gap"]

    property var values: defaults

    readonly property var apps: values.apps !== undefined ? values.apps : defaults.apps
    readonly property bool showRunning: values.showRunning !== undefined ? values.showRunning : defaults.showRunning
    readonly property bool bordered: values.bordered !== undefined ? values.bordered : defaults.bordered
    readonly property bool pushWindows: values.pushWindows !== undefined ? values.pushWindows : defaults.pushWindows
    readonly property bool edgeReveal: values.edgeReveal !== undefined ? values.edgeReveal : defaults.edgeReveal
    readonly property int revealDelay: values.revealDelay !== undefined ? values.revealDelay : defaults.revealDelay
    readonly property int hideDelay: values.hideDelay !== undefined ? values.hideDelay : defaults.hideDelay
    readonly property bool animate: values.animate !== undefined ? values.animate : defaults.animate
    readonly property var keys: values.keys !== undefined ? values.keys : defaults.keys

    signal changed()

    property string lastWritten: ""

    function clone(value) {
        return JSON.parse(JSON.stringify(value));
    }

    function serialize(value) {
        return JSON.stringify(value, null, 2) + "\n";
    }

    function set(key, value) {
        const next = clone(root.values);
        next[key] = value;
        apply(next);
    }

    function setApps(list) {
        set("apps", list);
    }

    // In-memory state updates immediately so the UI never lags a click; the
    // disk write is coalesced behind a short timer.
    function apply(next) {
        root.values = next;
        root.changed();
        writeTimer.restart();
    }

    function write() {
        writeTimer.stop();
        root.lastWritten = serialize(root.values);
        settleTimer.restart();
        file.setText(root.lastWritten);
    }

    function parse(text) {
        let parsed = {};
        try {
            parsed = JSON.parse(text);
            if (parsed === null || typeof parsed !== "object" || Array.isArray(parsed)) parsed = {};
        } catch (e) {
            // A half-written or hand-edited file should never take the dock
            // down; fall back to defaults and leave the file for the user.
            console.warn("duck: config.json is not valid JSON, using defaults:", e);
            parsed = {};
        }

        const merged = clone(root.defaults);
        for (const key in parsed) {
            if (root.retired.indexOf(key) !== -1) continue;
            merged[key] = parsed[key];
        }
        if (!Array.isArray(merged.apps)) merged.apps = [];

        root.values = merged;
        root.changed();
    }

    // FileView will not create missing directories, and a write into one that
    // does not exist is simply lost. setup.sh used to make this directory; the
    // plugin owns it now, so settings can be saved on a machine where setup.sh
    // was never run.
    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.configDir])

    Timer {
        id: writeTimer
        interval: 60
        onTriggered: root.write()
    }

    // How long after a write to keep ignoring reloads. Covers the watcher
    // event our own write causes, plus any read already in flight.
    Timer {
        id: settleTimer
        interval: 300
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        preload: true
        printErrors: false

        onFileChanged: reload()

        onLoaded: {
            const incoming = text();

            // Our own write echoing back through the watcher.
            if (incoming === root.lastWritten) return;

            // A read that started before the write landed would hand back stale
            // content and undo it.
            if (settleTimer.running) return;

            root.parse(incoming);
        }

        onLoadFailed: function (error) {
            // Usually just means the file does not exist yet. Run on defaults
            // rather than writing one back from inside a load callback.
            root.values = root.clone(root.defaults);
            root.changed();
        }
    }
}
