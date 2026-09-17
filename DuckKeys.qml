import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import "blocks.js" as Blocks

// Duck's Hyprland bindings and its one window rule, registered at runtime.
//
// These used to be installed into ~/.config/hypr/duck.lua by setup.sh, and a
// file there outlives the plugin. `omarchy plugin remove` deletes the plugin
// directory but nothing Duck wrote into the user's Hyprland config, so the
// bindings stayed — pointing at global shortcuts that no longer exist, and,
// worse, keeping Super+Ctrl+Left/Right unbound from Omarchy's grouped-window
// focus with nothing on screen to explain why those keys had gone dead.
//
// Registering through `hyprctl eval` keeps all of it in Hyprland's runtime
// state instead, which no config file records. Duck takes it back down on
// unload, and anything that escapes that — a shell killed outright — is erased
// by the next `hyprctl reload` rather than persisting.
//
// `hyprctl keyword` is not an option here: it is refused under the Lua parser,
// which answers "keyword can't work with non-legacy parsers. Use eval."
Item {
    id: root

    // Injected by Duck.qml rather than reached as a singleton, like the rest.
    required property var config

    // action name (the GlobalShortcut declared in Duck.qml) -> Hyprland key
    // string. Comes from config.json, so the keys stay the user's to change --
    // that is what hypr/duck.lua used to be for.
    readonly property var keys: root.config.keys

    // What each binding is called wherever the system lists it: Hyprland's own
    // bind table, Omarchy's keybindings viewer, and the global shortcut
    // registry. Not user text -- the keys are the user's to change, the names
    // of the actions are Duck's.
    //
    // "Duck", not "Dock". The dock is what it is; Duck is what it is called.
    readonly property var labels: ({
        "toggle": "Duck: open or close the dock",
        "activate": "Duck: launch the selected app",
        "prev": "Duck: select left (grouped-window focus while closed)",
        "next": "Duck: select right (grouped-window focus while closed)",
        "moveprev": "Duck: move the selected app left",
        "movenext": "Duck: move the selected app right",
        "unpin": "Duck: unpin the selected app",
        "hide": "Duck: close the dock"
    })

    function describe(action) {
        const label = root.labels[action];
        return label !== undefined ? label : "Duck: " + action;
    }

    // Only the actions that actually carry a key. An empty string means the
    // user cleared it, which has to read as "leave it alone", not as a bind to
    // the empty string.
    // These two strings are pasted into Lua source and handed to `hyprctl eval`,
    // so anything that could close the quote and keep going has to be refused
    // rather than escaped. A key string is modifiers, names and separators; an
    // action is a bare identifier naming a GlobalShortcut. Nothing legitimate
    // needs a quote, a bracket or a newline.
    //
    // config.json is the user's own file, so this is not a privilege boundary --
    // it is the difference between a typo being ignored and a typo running as
    // Lua inside the compositor.
    readonly property var safeCombo: /^[A-Za-z0-9_+:\- ]+$/
    readonly property var safeAction: /^[A-Za-z0-9_-]+$/

    function boundIn(map) {
        const list = [];
        const source = map || ({});

        for (const action in source) {
            const combo = (source[action] || "").toString().trim();
            if (combo.length === 0) continue;

            if (!root.safeAction.test(action)) {
                console.warn("duck: ignoring key for unusable action name", action);
                continue;
            }
            if (!root.safeCombo.test(combo)) {
                console.warn("duck: ignoring unusable key string for", action, "->", combo);
                continue;
            }

            list.push({ "action": action, "combo": combo });
        }
        return list;
    }

    function runLua(lua) {
        if (lua.length > 0) Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    // Unbind before binding, every time. Super+Ctrl+Left/Right carry Omarchy's
    // grouped-window focus, and on a machine still carrying the old
    // hypr/duck.lua the other two would end up bound twice over — every press
    // firing the action once from the config and once from here, which reads as
    // the dock opening and shutting again immediately.
    function apply() {
        const list = root.boundIn(root.keys);
        let lua = "";

        // The description is what names the binding to the rest of the system,
        // and it is not decoration: omarchy-menu-keybindings skips any bind that
        // has none, so without it Duck's keys are missing from the keybindings
        // list entirely. hl.bind takes it in an options table, the same way
        // Omarchy's own o.bind wrapper passes it.
        for (let i = 0; i < list.length; i++) {
            lua += 'hl.unbind("' + list[i].combo + '")\n';
            lua += 'hl.bind("' + list[i].combo + '", hl.dsp.global("duck:' + list[i].action + '"),'
                 + ' { description = [[' + root.describe(list[i].action) + ']] })\n';
        }

        // Long brackets, not quotes: the class pattern carries a backslash that
        // would otherwise need escaping through QML and Lua both.
        lua += 'hl.window_rule({ match = { class = [[^org\\.quickshell$]],'
             + ' title = [[^Duck Settings$]] },'
             + ' float = true, center = true, size = { 520, 720 } })\n';

        root.runLua(lua);
    }

    // Hand the arrows back on the way out. nav() already forwards to these two
    // whenever the dock is closed, so this is the behaviour Duck was standing in
    // front of rather than a guess at what Omarchy binds. A `hyprctl reload`
    // restores them too, which is what covers a shell that never got here.
    // Takes the map that was actually registered, never the current one. On a
    // key change those differ, and unbinding the new set would leave the key it
    // moved away from still captured.
    function revoke(map) {
        const list = root.boundIn(map);
        let lua = "";

        for (let i = 0; i < list.length; i++)
            lua += 'hl.unbind("' + list[i].combo + '")\n';

        // Only these two were ever Omarchy's -- Super+Ctrl+Up/Down are free, so
        // leaving them unbound is the correct end state rather than an omission.
        // Restoring by hand covers the common case; a `hyprctl reload` restores
        // whatever Omarchy actually binds today, which is the authority.
        for (let i = 0; i < list.length; i++) {
            if (list[i].combo === "SUPER + CTRL + LEFT")
                lua += 'hl.bind("SUPER + CTRL + LEFT", hl.dsp.group.prev())\n';
            else if (list[i].combo === "SUPER + CTRL + RIGHT")
                lua += 'hl.bind("SUPER + CTRL + RIGHT", hl.dsp.group.next())\n';
        }

        root.runLua(lua);
    }

    // The map as last handed to Hyprland, kept so a later change can be undone
    // against what was actually registered.
    property var applied: null

    function sync() {
        const spec = JSON.stringify(root.keys);
        if (root.applied !== null && JSON.stringify(root.applied) === spec) return;

        if (root.applied !== null) root.revoke(root.applied);
        root.applied = JSON.parse(spec);
        root.apply();
    }

    Component.onCompleted: {
        root.migrate();
        root.sync();
    }

    Component.onDestruction: root.revoke(root.applied)

    // --- migration ----------------------------------------------------------
    //
    // Versions through 1.0 installed ~/.config/hypr/duck.lua and a require line
    // in hyprland.lua. With setup.sh gone nothing else would ever remove them,
    // and left in place they keep Super+Ctrl+Left/Right captured on behalf of a
    // plugin that may not even be loaded. Duck clears its own past footprint.
    //
    // duck.lua is kept as a backup rather than deleted outright: it was
    // documented as the user's to edit.
    function migrate() {
        Quickshell.execDetached(["sh", "-c",
            '[ -f "$1" ] || exit 0\n'
            + '[ -e "$1.duck-backup" ] || cp "$1" "$1.duck-backup"\n'
            + 'rm -f "$1"',
            "sh", Quickshell.env("HOME") + "/.config/hypr/duck.lua"]);
    }

    // Read once, with no watcher: this file is nothing to do with Duck beyond
    // the block an older version left in it.
    FileView {
        id: hyprland

        path: Quickshell.env("HOME") + "/.config/hypr/hyprland.lua"
        preload: true
        printErrors: false

        onLoaded: {
            const current = text();
            const next = Blocks.strip(current, "--");
            if (next !== current) setText(next.replace(/\n+$/, "\n"));
        }
    }

    Connections {
        target: root.config
        function onChanged() { root.sync(); }
    }

    // A reload re-reads the config and drops every runtime binding with it, so
    // all of the above has to go back in afterwards.
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded") reapply.restart();
        }
    }

    // Debounced: the event arrives while Hyprland is still applying the config,
    // and a burst of reloads should cost one re-registration rather than one
    // apiece.
    Timer {
        id: reapply
        interval: 150
        onTriggered: root.apply()
    }
}
