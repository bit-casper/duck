import QtQuick
import Quickshell
import Quickshell.Io
import "blocks.js" as Blocks

// Duck's rows in the Omarchy menu (Super+Space).
//
// The menu reads exactly two fixed paths -- the shell's defaults and one user
// extension file -- with no drop-in directory beside either, so contributing
// rows means editing a file Duck does not own. It is the one edit left that
// setup.sh used to make, and doing it here instead means it is undone when the
// plugin unloads rather than waiting for a script the user has to remember.
//
// The shell watches this file, so rows appear and disappear without a restart.
Item {
    id: root

    readonly property string path: Quickshell.env("HOME")
        + "/.config/omarchy/extensions/omarchy-menu.jsonc"

    // JSONC, indented two spaces to sit with the menu's own rows.
    readonly property string prefix: "  //"

    readonly property var rows: [
        '  "duck": {"icon":"󰇥","label":"Duck","description":"Dock settings and controls","aliases":["dock"]},',
        '  "duck.settings": {"icon":"󰒓","label":"Settings","action":"duck settings"},',
        '  "duck.toggle": {"icon":"","label":"Toggle dock","action":"duck toggle"},',
        '  "duck.restart": {"icon":"","label":"Restart dock","action":"duck restart"},'
    ]

    // Our own write echoing back through the watcher, ignored the way
    // DuckConfig ignores its own.
    property string lastWritten: ""
    property bool attemptedCreate: false

    function install(current) {
        const next = Blocks.write(current, root.prefix, root.rows);

        // null means no closing brace to insert before: not a file Duck should
        // be writing into, whatever it is.
        if (next === null || next === current) return;

        root.lastWritten = next;
        file.setText(next);
    }

    // One attempt only. If the directory cannot be made there is nothing to be
    // gained by trying again on every reload.
    function create() {
        if (root.attemptedCreate) return;
        root.attemptedCreate = true;

        Quickshell.execDetached(["sh", "-c",
            'mkdir -p "$(dirname "$1")" || exit 0\n'
            + '[ -e "$1" ] || printf "{\\n}\\n" >"$1"',
            "sh", root.path]);

        settle.restart();
    }

    Timer {
        id: settle
        interval: 400
        onTriggered: file.reload()
    }

    FileView {
        id: file

        path: root.path
        watchChanges: true
        preload: true
        printErrors: false

        onLoaded: {
            const current = text();
            if (current === root.lastWritten) return;
            root.install(current);
        }

        onFileChanged: reload()
        onLoadFailed: root.create()
    }

    // Reached on plugin disable, and on `omarchy plugin remove` because that
    // disables before it deletes.
    Component.onDestruction: {
        const current = file.text();
        if (!current) return;

        const next = Blocks.strip(current, root.prefix);
        if (next !== current) file.setText(next);
    }
}
