//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Duck — a dynamic dock for Omarchy.
//
// One dock per screen, plus an IPC surface that the `duck` CLI and the Hyprland
// keybinding talk to. Run directly with `qs -c duck`.
ShellRoot {
    id: shell

    property bool settingsOpen: false

    // A dock per monitor; Variants keeps them in step as screens come and go.
    Variants {
        id: docks

        model: Quickshell.screens

        Dock {}
    }

    function eachDock(fn) {
        const instances = docks.instances;
        for (let i = 0; i < instances.length; i++) fn(instances[i]);
    }

    // Raising by key targets the focused screen only; edge-hover handles the rest.
    function activeDock() {
        const instances = docks.instances;
        for (let i = 0; i < instances.length; i++) {
            const focused = Hyprland.focusedMonitor;
            if (focused && instances[i].screen && instances[i].screen.name === focused.name) return instances[i];
        }
        return instances.length > 0 ? instances[0] : null;
    }

    LazyLoader {
        id: settingsLoader

        active: shell.settingsOpen

        SettingsWindow {
            // FloatingWindow has no close signal; closing the window clears
            // `visible`, which is what tears the loader back down.
            property bool everShown: false

            onVisibleChanged: {
                if (visible) everShown = true;
                else if (everShown) shell.settingsOpen = false;
            }
        }
    }

    IpcHandler {
        target: "dock"

        // Named `reveal`, not `show`: `show` is a reserved `qs ipc` subcommand
        // and a handler function by that name can never be called.
        function reveal(): void {
            const dock = shell.activeDock();
            if (dock) dock.show(true);
        }

        function hide(): void {
            shell.eachDock(function (dock) { dock.hide(); });
        }

        function toggle(): void {
            const dock = shell.activeDock();
            if (!dock) return;
            if (dock.open) shell.eachDock(function (d) { d.hide(); });
            else dock.show(true);
        }

        function settings(): void {
            shell.settingsOpen = true;
        }

        function add(id: string): string {
            const entry = Apps.entryFor(id);
            if (!entry) return "no application matching '" + id + "'";
            if (!Apps.pin(entry.id)) return entry.name + " is already pinned";
            return "pinned " + entry.name + " (" + entry.id + ")";
        }

        function remove(id: string): string {
            if (!Apps.unpin(id)) return "'" + id + "' is not pinned";
            return "unpinned " + id;
        }

        function list(): string {
            const apps = Config.apps;
            if (apps.length === 0) return "(nothing pinned)";

            let out = "";
            for (let i = 0; i < apps.length; i++) {
                const entry = Apps.entryFor(apps[i]);
                out += (i + 1) + ". " + (entry ? entry.name : apps[i] + "  (not found)") + "\n";
            }
            return out.trim();
        }

        function set(key: string, value: string): string {
            if (Config.defaults[key] === undefined) return "unknown setting '" + key + "'";

            const current = Config.defaults[key];
            let parsed = value;

            if (typeof current === "boolean") parsed = (value === "true" || value === "1" || value === "on");
            else if (typeof current === "number") parsed = parseInt(value, 10);

            if (typeof parsed === "number" && isNaN(parsed)) return "'" + value + "' is not a number";

            Config.set(key, parsed);
            return key + " = " + parsed;
        }
    }
}
