import QtQuick
import Quickshell
import Quickshell.Io

// Icon resolution with a filesystem fallback.
//
// Qt's themed lookup misses icons that only exist in the `hicolor` fallback
// theme (Ghostty is one), returning an empty path and leaving the dock full of
// generic placeholders. So we keep our own index of every app icon on disk and
// fall back to it whenever the themed lookup comes up empty.
Item {
    id: root

    readonly property string fallback: Quickshell.iconPath("application-x-executable")

    // icon name -> best file on disk
    property var index: ({})
    property bool ready: false

    signal indexed()

    function rank(path) {
        // Scalable beats bitmap; otherwise prefer the largest available size.
        if (path.indexOf("/scalable/") !== -1 || path.slice(-4) === ".svg") return 100000;
        const match = /\/(\d+)x\1(@\d+)?\//.exec(path);
        if (!match) return 1;
        const size = parseInt(match[1], 10);
        // Cap it: a 1024px PNG for a 44px slot is wasteful to decode.
        return size > 512 ? 512 - (size - 512) / 100 : size;
    }

    function ingest(paths) {
        const built = {};

        for (let i = 0; i < paths.length; i++) {
            const path = paths[i];
            if (!path) continue;

            const slash = path.lastIndexOf("/");
            const dot = path.lastIndexOf(".");
            if (slash === -1 || dot <= slash) continue;

            const name = path.substring(slash + 1, dot);
            const score = rank(path);

            if (!built[name] || score > built[name].score)
                built[name] = { "path": path, "score": score };
        }

        const flat = {};
        for (const name in built) flat[name] = built[name].path;

        root.index = flat;
        root.ready = true;
        root.indexed();
    }

    // Returns a source URL usable by Image/IconImage.
    function source(icon) {
        const name = (icon || "").toString();
        if (name.length === 0) return root.fallback;

        // Desktop entries may carry an absolute path instead of a theme name.
        // Only a plain file is honoured: `image://` would let an entry Duck does
        // not control address a QML image provider, and no real .desktop file has
        // any reason to name one. Anything else falls through to theme lookup.
        if (name.indexOf("file://") === 0) return name;
        if (name.charAt(0) === "/") return "file://" + name;

        const themed = Quickshell.iconPath(name, true);
        if (themed && themed.length > 0) return themed;

        const found = root.index[name];
        if (found) return "file://" + found;

        // Some entries name the icon in a different case than the file.
        const lower = name.toLowerCase();
        for (const key in root.index) {
            if (key.toLowerCase() === lower) return "file://" + root.index[key];
        }

        return root.fallback;
    }

    Process {
        id: scan

        running: true
        command: [
            "sh", "-c",
            "find /usr/share/icons /usr/share/pixmaps " +
            "\"$HOME/.local/share/icons\" " +
            "\"$HOME/.local/share/flatpak/exports/share/icons\" " +
            "/var/lib/flatpak/exports/share/icons " +
            "\\( -path '*/apps/*' -o -path '/usr/share/pixmaps/*' \\) " +
            "\\( -name '*.png' -o -name '*.svg' -o -name '*.xpm' \\) 2>/dev/null"
        ]

        stdout: StdioCollector {
            onStreamFinished: root.ingest(text.split("\n"))
        }
    }

    // Newly installed apps should get their icon without a restart.
    function refresh() {
        if (!scan.running) scan.running = true;
    }
}
