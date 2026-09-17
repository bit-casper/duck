import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Duck — a dock for Omarchy.
//
// Loaded by the Omarchy shell as a `panel` plugin, so this is a plain Item
// rather than a ShellRoot: the shell owns the process, and Duck mounts its own
// layer-shell surfaces underneath.
//
// Omarchy's plugins avoid QML singletons — nothing here is `pragma Singleton`.
// State lives on this root and is handed to the docks explicitly, which is also
// what keeps a second screen from quietly sharing the first one's state.
Item {
    id: root

    readonly property alias config: configState
    readonly property alias apps: appsState
    readonly property alias icons: iconsState
    readonly property alias hypr: hyprState

    property bool settingsOpen: false

    DuckConfig { id: configState }
    DuckIcons { id: iconsState }
    DuckHypr { id: hyprState }

    // Registers Duck's keybindings and window rule with the running Hyprland
    // rather than writing them into the user's config, so removing the plugin
    // cannot leave them behind.
    DuckKeys {
        id: keysState
        config: configState
    }

    // The two things a plugin still cannot declare: a command on PATH and rows
    // in the Omarchy menu. Both are made on load and unmade on unload, so no
    // install script owns them.
    DuckCli { id: cliState }
    DuckMenu { id: menuState }

    DuckApps {
        id: appsState
        config: configState
        icons: iconsState
    }

    // One dock per monitor; Variants keeps them in step as screens come and go.
    Variants {
        id: docks

        model: Quickshell.screens

        Dock { duck: root }
    }

    function eachDock(fn) {
        const instances = docks.instances;
        for (let i = 0; i < instances.length; i++) fn(instances[i]);
    }

    // Keyboard actions target the focused screen; edge-hover handles the rest.
    function activeDock() {
        const instances = docks.instances;
        const focused = Hyprland.focusedMonitor;

        for (let i = 0; i < instances.length; i++) {
            if (focused && instances[i].screen && instances[i].screen.name === focused.name)
                return instances[i];
        }
        return instances.length > 0 ? instances[0] : null;
    }

    function nav(action) {
        const dock = activeDock();
        if (dock) dock.nav(action);
    }

    LazyLoader {
        id: settingsLoader

        active: root.settingsOpen

        Settings {
            duck: root

            // FloatingWindow has no close signal; closing clears `visible`,
            // which is what tears the loader back down.
            property bool everShown: false

            onVisibleChanged: {
                if (visible) everShown = true;
                else if (everShown) root.settingsOpen = false;
            }
        }
    }

    // --- keyboard -----------------------------------------------------------
    //
    // Global shortcuts rather than a keyboard grab: a grab routes every
    // keystroke to the dock and leaves the desktop feeling frozen. The bindings
    // that point at these live in hypr/duck.lua.
    //
    // Declared one by one on purpose — a Repeater is a visual type and will not
    // instantiate its delegates here, which silently registers nothing.
    component DockShortcut: GlobalShortcut {
        required property string action

        appid: "duck"
        // Same names the Hyprland bindings carry, so `hyprctl globalshortcuts`
        // and the bind table agree with each other.
        description: keysState.describe(action)

        onPressed: root.nav(action)
    }

    DockShortcut { name: "toggle"; action: "toggle" }
    DockShortcut { name: "prev"; action: "prev" }
    DockShortcut { name: "next"; action: "next" }
    DockShortcut { name: "moveprev"; action: "moveprev" }
    DockShortcut { name: "movenext"; action: "movenext" }
    DockShortcut { name: "activate"; action: "activate" }
    DockShortcut { name: "unpin"; action: "unpin" }

    GlobalShortcut {
        appid: "duck"
        name: "hide"
        description: keysState.describe("hide")

        onPressed: root.eachDock(function (dock) { dock.hide(); })
    }

    // --- IPC ----------------------------------------------------------------
    //
    // Reached with `omarchy-shell duck <method>`, which is what the `duck` CLI
    // talks to.
    IpcHandler {
        target: "duck"

        // Named `reveal`, not `show`: `show` is a reserved ipc subcommand and a
        // handler function by that name can never be called.
        function reveal(): void {
            const dock = root.activeDock();
            if (dock) dock.show(true);
        }

        function hide(): void {
            root.eachDock(function (dock) { dock.hide(); });
        }

        function toggle(): void {
            root.nav("toggle");
        }

        function settings(): void {
            root.settingsOpen = true;
        }

        function nav(action: string): void {
            root.nav(action);
        }

        function add(id: string): string {
            const entry = root.apps.entryFor(id);
            if (!entry) return "no application matching '" + id + "'";
            if (!root.apps.pin(entry.id)) return entry.name + " is already pinned";
            return "pinned " + entry.name + " (" + entry.id + ")";
        }

        function remove(id: string): string {
            if (!root.apps.unpin(id)) return "'" + id + "' is not pinned";
            return "unpinned " + id;
        }

        function list(): string {
            const pinned = root.config.apps;
            if (pinned.length === 0) return "(nothing pinned)";

            let out = "";
            for (let i = 0; i < pinned.length; i++) {
                const entry = root.apps.entryFor(pinned[i]);
                out += (i + 1) + ". " + (entry ? entry.name : pinned[i] + "  (not found)") + "\n";
            }
            return out.trim();
        }

        function set(key: string, value: string): string {
            // Own properties only. Testing `defaults[key] !== undefined` reaches
            // the prototype too, so `constructor`, `toString`, `valueOf` and
            // `hasOwnProperty` all read as real settings and get written to
            // config.json as keys of their own.
            if (!Object.prototype.hasOwnProperty.call(root.config.defaults, key))
                return "unknown setting '" + key + "'";

            // `apps` is a list, and every other route into it resolves a desktop
            // id first. Assigning it here would store the raw string: the dock
            // then indexes it a character at a time, the watcher ignores the
            // write because it is our own, and the pinned list is already gone
            // from disk by the time a restart parses it back to empty. The CLI
            // has always refused this; the IPC path never did.
            if (key === "apps")
                return "'apps' is a list — use `duck add` and `duck rm`";

            const current = root.config.defaults[key];

            let parsed = value;
            if (typeof current === "boolean") parsed = (value === "true" || value === "1" || value === "on");
            else if (typeof current === "number") parsed = parseInt(value, 10);

            if (typeof parsed === "number" && isNaN(parsed)) return "'" + value + "' is not a number";

            root.config.set(key, parsed);
            return key + " = " + parsed;
        }
    }
}
