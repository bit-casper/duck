pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live view of the current Omarchy theme.
//
// Colors come from the generated colors.toml that `omarchy theme set` writes, so
// Duck restyles itself the moment the user switches themes. Border width is read
// from Hyprland so a bordered dock matches real windows exactly.
Singleton {
    id: root

    readonly property string colorsPath: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme/colors.toml"

    property string mode: "dark"
    property color background: "#11111b"
    property color darkBackground: "#0d0d15"
    property color foreground: "#cdd6f4"
    property color accent: "#89b4fa"
    property color muted: "#6c7086"

    // Matched to Hyprland's general:border_size so bordered mode lines up with windows.
    property int borderWidth: 2

    readonly property bool isDark: mode !== "light"

    signal reloaded()

    function parse(text) {
        const found = {};
        const lines = text.split("\n");

        for (let i = 0; i < lines.length; i++) {
            // colors.toml is flat `key = "value"`; no need for a real TOML parser.
            const match = /^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*"([^"]*)"\s*$/.exec(lines[i]);
            if (match) found[match[1]] = match[2];
        }

        if (found.mode) root.mode = found.mode;
        if (found.background) root.background = found.background;
        if (found.dark_background) root.darkBackground = found.dark_background;
        if (found.foreground) root.foreground = found.foreground;
        if (found.accent) root.accent = found.accent;
        if (found.muted) root.muted = found.muted;

        root.reloaded();
    }

    FileView {
        path: root.colorsPath
        watchChanges: true
        preload: true
        printErrors: false

        onFileChanged: reload()
        onLoaded: root.parse(text())
    }

    Process {
        id: borderProbe

        running: true
        command: ["hyprctl", "getoption", "general:border_size", "-j"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text).int;
                    if (typeof value === "number" && value >= 0) root.borderWidth = value;
                } catch (e) {
                    // Keep the default; a wrong border width is cosmetic, not fatal.
                }
            }
        }
    }

    // Hyprland rewrites its config on theme change, so re-probe when colors move.
    onReloaded: borderProbe.running = true
}
