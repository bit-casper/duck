import QtQuick
import Quickshell

// The `duck` command on PATH.
//
// A plugin cannot put anything on PATH by itself: `omarchy` discovers commands
// only from its own bin directory, and no plugin directory is on PATH. So the
// CLI is reached through a symlink in ~/.local/bin, made when Duck loads and
// taken away when it unloads.
//
// Anything already at that path that is not a symlink is left strictly alone.
// setup.sh used to move a stranger's `duck` aside to duck.bak.<timestamp>, which
// is both destructive and left a file nothing ever cleaned up; declining to
// touch it has neither problem.
Item {
    id: root

    // The plugin's own directory, wherever it was installed.
    readonly property string target: Qt.resolvedUrl("bin/duck").toString().replace("file://", "")
    readonly property string link: Quickshell.env("HOME") + "/.local/bin/duck"

    // Arguments rather than interpolation: the plugin path is whatever the user
    // installed into, and a space in it should not become two words.
    Component.onCompleted: Quickshell.execDetached(["sh", "-c",
        'mkdir -p "$(dirname "$2")" || exit 0\n'
        + 'if [ -L "$2" ] || [ ! -e "$2" ]; then\n'
        + '  ln -sfn "$1" "$2"\n'
        + 'else\n'
        + '  echo "duck: $2 already exists and is not a symlink; leaving it alone" >&2\n'
        + 'fi',
        "sh", root.target, root.link])

    // Only if it still points at this plugin -- a link replaced by something
    // else in the meantime belongs to whoever replaced it.
    Component.onDestruction: Quickshell.execDetached(["sh", "-c",
        '[ -L "$2" ] || exit 0\n'
        + '[ "$(readlink -f "$2" 2>/dev/null)" = "$(readlink -f "$1" 2>/dev/null)" ] && rm -f "$2"',
        "sh", root.target, root.link])
}
