import QtQuick
import Quickshell
import Quickshell.Wayland

// Turns the pinned-id list plus the compositor's window list into the dock model.
//
// Passing every dependency as an explicit argument to buildItems() is what makes
// `items` re-evaluate when apps are pinned, a window opens, or the setting flips.
Item {
    id: root

    // Injected by Duck.qml rather than reached as singletons.
    required property var config
    required property var icons

    // DesktopEntries fills in asynchronously after startup, one entry at a time.
    // It is passed through as an explicit dependency so `items` re-resolves as
    // entries arrive — without it the dock renders placeholder icons forever.
    readonly property var entries: DesktopEntries.applications.values

    readonly property var items: buildItems(root.config.apps, root.config.showRunning,
                                            ToplevelManager.toplevels.values, entries,
                                            root.icons.index)

    // Desktop ids, window app-ids and WM_CLASS values disagree about case and
    // reverse-DNS prefixes, so compare on a flattened form.
    function normalize(value) {
        if (!value) return "";
        return value.toString().toLowerCase().replace(/\.desktop$/, "");
    }

    function lastSegment(value) {
        const flat = normalize(value);
        const dot = flat.lastIndexOf(".");
        return dot === -1 ? flat : flat.substring(dot + 1);
    }


    // Proton games launched through umu arrive with a window app-id of
    // `steam_app_<gameid>`, where the gameid is what GAMEID= was set to without
    // its `umu-` prefix. Omarchy's Battle.net launcher sets GAMEID=umu-battlenet,
    // so the window turns up as `steam_app_battlenet` while its desktop entry is
    // plain `battlenet`, and nothing in entryFor() brings the two together --
    // the entry even declares StartupWMClass=battle.net.exe, which is not what
    // the window ends up carrying either.
    //
    // A real Steam title uses a numeric id (`steam_app_440`) that names no
    // desktop file, so those are left alone rather than guessed at.
    function unwrapLauncher(appId) {
        const match = /^steam_app_(.+)$/.exec(normalize(appId));
        if (!match || /^\d+$/.test(match[1])) return "";
        return match[1];
    }

    // Omarchy runs many "apps" as browser PWAs. Their window app-id looks like
    // `brave-discord.gg__tXFUdasqhY-Default`, which matches no desktop file, so
    // they would all collapse onto the generic icon. Recover the site from the
    // app-id and find the webapp entry that launches it.
    function webAppEntry(appId) {
        const match = /^(?:brave|chrome|chromium|google-chrome|msedge)-([a-z0-9.-]+?)(?:__[^-]*)?-(?:default|profile.*)$/
            .exec(normalize(appId));
        if (!match) return null;

        const host = match[1];
        // `discord.gg` and `discord.com` are the same app to a person.
        const label = host.split(".")[0];
        const all = DesktopEntries.applications.values;
        let loose = null;

        for (let i = 0; i < all.length; i++) {
            const entry = all[i];
            const exec = (entry.execString || entry.command || "").toString().toLowerCase();

            if (exec.indexOf(host) !== -1) return entry;
            if (!loose && label.length > 2) {
                if (normalize(entry.name) === label) loose = entry;
                else if (exec.indexOf("//" + label + ".") !== -1) loose = entry;
                else if (exec.indexOf("//www." + label + ".") !== -1) loose = entry;
            }
        }

        return loose;
    }

    function entryFor(id) {
        if (!id) return null;

        const direct = DesktopEntries.byId(id);
        if (direct) return direct;

        // heuristicLookup misses reverse-DNS ids entirely, so search the model.
        // Tolerates `ghostty` for `com.mitchellh.ghostty`, and window app-ids
        // whose case does not match the desktop file.
        const target = normalize(id);
        const tail = lastSegment(id);
        const all = DesktopEntries.applications.values;
        let tailMatch = null;

        for (let i = 0; i < all.length; i++) {
            const entry = all[i];
            if (normalize(entry.id) === target) return entry;
            if (entry.startupClass && normalize(entry.startupClass) === target) return entry;
            if (!tailMatch && lastSegment(entry.id) === tail) tailMatch = entry;
        }

        if (tailMatch) return tailMatch;

        const unwrapped = unwrapLauncher(id);
        if (unwrapped.length > 0) {
            // Terminates: the unwrapped id no longer carries the prefix.
            const viaLauncher = entryFor(unwrapped);
            if (viaLauncher) return viaLauncher;
        }

        return webAppEntry(id);
    }

    function matchesId(entry, appId) {
        const target = normalize(appId);
        if (normalize(entry.id) === target) return true;
        if (entry.startupClass && normalize(entry.startupClass) === target) return true;
        // Last resort: `ghostty` should still match `com.mitchellh.ghostty`.
        return lastSegment(entry.id) === lastSegment(appId);
    }

    // Has to unwrap too, not just entryFor: without it a pinned Battle.net never
    // claims its own running window, so the dock shows the app twice -- once
    // pinned with the right icon, once as a stranger with the fallback one.
    function matches(entry, appId) {
        if (!entry || !appId) return false;
        if (matchesId(entry, appId)) return true;

        const unwrapped = unwrapLauncher(appId);
        return unwrapped.length > 0 && matchesId(entry, unwrapped);
    }

    // Quickshell surfaces are shell chrome, not apps — Duck's own settings
    // window would otherwise show up as an icon in Duck's own dock.
    function isShellWindow(toplevel) {
        return normalize(toplevel.appId) === "org.quickshell";
    }

    function buildItems(pinnedIds, showRunning, toplevels, entries, iconIndex) {
        const result = [];
        const claimed = [];
        const windows = [];

        const all = toplevels || [];
        for (let i = 0; i < all.length; i++) {
            if (!isShellWindow(all[i])) windows.push(all[i]);
        }

        for (let i = 0; i < pinnedIds.length; i++) {
            const id = pinnedIds[i];
            const entry = entryFor(id);
            const mine = [];

            for (let w = 0; w < windows.length; w++) {
                if (matches(entry, windows[w].appId)) {
                    mine.push(windows[w]);
                    claimed.push(windows[w]);
                }
            }

            result.push({
                "key": "pin:" + id,
                "id": id,
                "entry": entry,
                "name": entry ? entry.name : id,
                "icon": root.icons.source(entry ? entry.icon : ""),
                "pinned": true,
                "windows": mine,
                "running": mine.length > 0,
                // Unresolvable ids still render, so a typo is visible rather than silent.
                "missing": entry === null
            });
        }

        if (!showRunning) return result;

        // Group the leftover windows by app so five terminals share one dock icon.
        const groups = {};
        const order = [];

        for (let w = 0; w < windows.length; w++) {
            const top = windows[w];
            if (claimed.indexOf(top) !== -1) continue;

            const key = normalize(top.appId) || "unknown";
            if (!groups[key]) {
                groups[key] = [];
                order.push(key);
            }
            groups[key].push(top);
        }

        for (let i = 0; i < order.length; i++) {
            const key = order[i];
            const group = groups[key];
            const entry = entryFor(group[0].appId);

            result.push({
                "key": "run:" + key,
                "id": entry ? entry.id : group[0].appId,
                "entry": entry,
                "name": entry ? entry.name : (group[0].title || group[0].appId),
                "icon": root.icons.source(entry ? entry.icon : ""),
                "pinned": false,
                "windows": group,
                "running": true,
                "missing": false
            });
        }

        return result;
    }

    // --- mutations, all routed through Config so the JSON file stays canonical ---

    function pin(id) {
        return pinAt(id, root.config.apps.length);
    }

    // Pin at a specific position. Dragging a running-but-unpinned icon lands
    // here: it has no stored position yet, so the drop decides it.
    function pinAt(id, index) {
        const entry = entryFor(id);
        const resolved = entry ? entry.id : id;
        const list = root.config.apps.slice();

        if (list.indexOf(resolved) !== -1) return false;

        const target = Math.max(0, Math.min(list.length, index));
        list.splice(target, 0, resolved);
        root.config.setApps(list);
        return true;
    }

    function unpin(id) {
        const entry = entryFor(id);
        const resolved = entry ? entry.id : id;
        const list = root.config.apps.slice();

        let index = list.indexOf(resolved);
        if (index === -1) index = list.indexOf(id);
        if (index === -1) return false;

        list.splice(index, 1);
        root.config.setApps(list);
        return true;
    }

    function move(from, to) {
        const list = root.config.apps.slice();
        if (from < 0 || from >= list.length) return false;

        const clamped = Math.max(0, Math.min(list.length - 1, to));
        if (clamped === from) return false;

        list.splice(clamped, 0, list.splice(from, 1)[0]);
        root.config.setApps(list);
        return true;
    }

    // Clicking a dock icon: focus what is already open, otherwise launch it.
    function activate(item) {
        if (item.windows && item.windows.length > 0) {
            // Cycle when the app's own window already has focus.
            let index = 0;
            for (let i = 0; i < item.windows.length; i++) {
                if (item.windows[i].activated) {
                    index = (i + 1) % item.windows.length;
                    break;
                }
            }
            item.windows[index].activate();
            return;
        }
        launch(item);
    }

    function launch(item) {
        if (!item.entry) {
            console.warn("duck: no desktop entry for", item.id);
            return;
        }

        // Quickshell's execute() runs the bare Exec line and does not act on
        // Terminal=true — it exposes runInTerminal separately and leaves the
        // decision to the shell. A TUI started that way gets no tty and exits
        // immediately, so the icon simply does nothing when clicked.
        //
        // Hand those to Omarchy's own launcher rather than picking a terminal
        // here: it opens whichever one `omarchy default terminal` selected, so
        // the choice stays in the one place the user already sets it. It also
        // starts the app under uwsm rather than as a child of the shell, which
        // is what keeps it alive across a shell restart.
        //
        // The window that appears belongs to the terminal emulator, not to the
        // app: it carries the emulator's app-id and only the title names the
        // TUI. --app-id asks for better, and terminals that implement it (foot)
        // oblige, but ghostty ignores it. So a TUI never joins `windows` and the
        // running dot stays dark for it. Matching it back by title is the only
        // other handle, and a TUI that writes its state into the title — a music
        // player naming the current track — slips straight out of it again.
        if (item.entry.runInTerminal) {
            const appId = item.entry.startupClass || item.entry.id;
            const argv = ["omarchy-launch-tui", "--app-id=" + appId];
            const command = item.entry.command;

            for (let i = 0; i < command.length; i++) argv.push(command[i]);
            Quickshell.execDetached(argv);
            return;
        }

        item.entry.execute();
    }
}
