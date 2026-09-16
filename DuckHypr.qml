import QtQuick
import Quickshell
import Quickshell.Io

// The few Hyprland values Omarchy's Style does not carry.
//
// Style already mirrors decoration:rounding and general:gaps_out, but stores
// the gap halved and does not expose general:border_size at all — and a dock
// that means to be indistinguishable from a window needs both exactly.
Item {
    id: root

    property int borderWidth: 2
    property int windowGap: 10

    Process {
        id: probe

        running: true
        command: ["sh", "-c",
            "hyprctl getoption general:border_size -j; hyprctl getoption general:gaps_out -j"]

        stdout: StdioCollector {
            onStreamFinished: {
                // Two concatenated JSON objects; walk them by brace depth.
                const docs = [];
                let depth = 0;
                let start = -1;

                for (let i = 0; i < text.length; i++) {
                    const ch = text.charAt(i);
                    if (ch === "{") {
                        if (depth === 0) start = i;
                        depth++;
                    } else if (ch === "}") {
                        depth--;
                        if (depth === 0 && start >= 0) {
                            docs.push(text.substring(start, i + 1));
                            start = -1;
                        }
                    }
                }

                try {
                    if (docs.length > 0) {
                        const value = JSON.parse(docs[0]).int;
                        if (typeof value === "number" && value >= 0) root.borderWidth = value;
                    }
                    if (docs.length > 1) {
                        // "css": "10 10 10 10" (top right bottom left)
                        const css = JSON.parse(docs[1]).css;
                        if (css) {
                            const parts = css.toString().trim().split(/\s+/);
                            const bottom = parts.length >= 3 ? parseInt(parts[2], 10) : parseInt(parts[0], 10);
                            if (!isNaN(bottom)) root.windowGap = bottom;
                        }
                    }
                } catch (e) {
                    // Cosmetic only — keep the defaults.
                }
            }
        }
    }

    function refresh() {
        if (!probe.running) probe.running = true;
    }
}
