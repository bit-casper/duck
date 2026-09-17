import QtQuick
import Quickshell
import Quickshell.Hyprland

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

    // Only the actions that actually carry a key. An empty string means the
    // user cleared it, which has to read as "leave it alone", not as a bind to
    // the empty string.
    function bound() {
        const list = [];
        const map = root.keys || ({});

        for (const action in map) {
            const combo = (map[action] || "").toString().trim();
            if (combo.length > 0) list.push({ "action": action, "combo": combo });
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
        const list = root.bound();
        let lua = "";

        for (let i = 0; i < list.length; i++) {
            lua += 'hl.unbind("' + list[i].combo + '")\n';
            lua += 'hl.bind("' + list[i].combo + '", hl.dsp.global("duck:' + list[i].action + '"))\n';
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
    function revoke() {
        const list = root.bound();
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

    // Changing a key in config.json has to take the old one back out, so the
    // previous set is revoked against the spec that registered it.
    property string appliedSpec: ""

    function sync() {
        const spec = JSON.stringify(root.keys);
        if (spec === root.appliedSpec) return;

        if (root.appliedSpec.length > 0) root.revoke();
        root.appliedSpec = spec;
        root.apply();
    }

    Component.onCompleted: root.sync()
    Component.onDestruction: root.revoke()

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
