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

    // Hyprland key string -> the GlobalShortcut name declared in Duck.qml.
    readonly property var bindings: [
        { "keys": "SUPER + CTRL + DOWN", "action": "toggle" },
        { "keys": "SUPER + CTRL + UP", "action": "activate" },
        { "keys": "SUPER + CTRL + LEFT", "action": "prev" },
        { "keys": "SUPER + CTRL + RIGHT", "action": "next" }
    ]

    function runLua(lua) {
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }

    // Unbind before binding, every time. Super+Ctrl+Left/Right carry Omarchy's
    // grouped-window focus, and on a machine still carrying the old
    // hypr/duck.lua the other two would end up bound twice over — every press
    // firing the action once from the config and once from here, which reads as
    // the dock opening and shutting again immediately.
    function apply() {
        let lua = "";

        for (let i = 0; i < root.bindings.length; i++) {
            const binding = root.bindings[i];
            lua += 'hl.unbind("' + binding.keys + '")\n';
            lua += 'hl.bind("' + binding.keys + '", hl.dsp.global("duck:' + binding.action + '"))\n';
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
        let lua = "";

        for (let i = 0; i < root.bindings.length; i++)
            lua += 'hl.unbind("' + root.bindings[i].keys + '")\n';

        lua += 'hl.bind("SUPER + CTRL + LEFT", hl.dsp.group.prev())\n';
        lua += 'hl.bind("SUPER + CTRL + RIGHT", hl.dsp.group.next())\n';

        root.runLua(lua);
    }

    Component.onCompleted: root.apply()
    Component.onDestruction: root.revoke()

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
