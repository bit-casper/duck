# Duck

A dynamic dock for [Omarchy](https://omarchy.org/). Hidden by default, slides up
from the bottom edge, themed from whatever Omarchy theme is active.

Built on [Quickshell](https://quickshell.org/) — the same engine as Omarchy's own
bar — so it uses real `wlr-layer-shell` surfaces rather than a floating window.

## Install

```bash
./install.sh
duck add ghostty chromium
duck start
```

`install.sh` symlinks the shell into `~/.config/quickshell/duck` and the CLI into
`~/.local/bin`, then adds a keybinding, an autostart entry, and a float rule for
the settings window to your Hyprland config. Every edit is appended once and the
original file is backed up first.

## Using it

The dock stays hidden until you ask for it:

| Action | Result |
|---|---|
| Move the mouse to the bottom edge | Dock slides up |
| `SUPER + CTRL + DOWN` | Dock slides up and takes the keyboard |
| `←` / `→` | Select an app |
| `SHIFT` + `←` / `→` | Move the selected app along the dock |
| `ENTER` | Launch it, or focus it if already running |
| `DELETE` | Unpin the selected app |
| `ESC` | Dismiss |

With the mouse: left-click launches or focuses, middle-click always opens a new
window, right-click pins or unpins, and dragging an icon reorders the dock.

Apps you have pinned always show. Apps that are running but not pinned are
appended after them, and a dot under an icon means it has windows open — one dot
per window, up to three. Turn that off in settings to make Duck a pure launcher.

## CLI

```bash
duck add ghostty          # pin (fuzzy: resolves to com.mitchellh.ghostty)
duck rm ghostty           # unpin
duck list                 # pinned apps, in order
duck move ghostty 1       # reorder
duck search term          # find installed apps

duck show | hide | toggle
duck settings             # open the settings window

duck set bordered false   # change a setting
duck get                  # show all settings

duck start | stop | restart | status
```

## Settings

`duck settings` opens a GUI, or edit `~/.config/duck/config.json` directly —
the running dock watches the file and applies changes live.

| Key | Default | Meaning |
|---|---|---|
| `apps` | `[]` | Pinned desktop entry ids, in dock order |
| `bordered` | `true` | Square themed border and solid background. When `false`, no border and a gradient fading up from the bottom edge |
| `pushWindows` | `false` | `true` reserves space so windows resize around the dock; `false` overlays them |
| `showRunning` | `true` | Append running-but-unpinned apps, and show running dots |
| `edgeReveal` | `true` | Reveal when the mouse reaches the bottom edge |
| `iconSize` | `44` | Icon size in px |
| `padding` | `8` | Space above and below the icons |
| `revealDelay` | `90` | ms of edge hover before revealing |
| `hideDelay` | `350` | ms after leaving before hiding |
| `animate` | `true` | Slide and hover transitions |

## Theming

Colors are read live from `~/.local/state/omarchy/current/theme/colors.toml`, and
the border width from Hyprland's `general:border_size`, so a bordered dock matches
your windows exactly. Run `omarchy theme set <name>` and the dock follows without
a restart.

## Layout

```
shell/            Quickshell config (QML)
  shell.qml         Root: one dock per screen, plus the IPC surface
  Dock.qml          The layer-shell panel: reveal, keyboard, drag-reorder
  DockItem.qml      A single icon
  Config.qml        config.json, watched and hot-reloaded
  Theme.qml         Omarchy theme colors
  Icons.qml         Icon resolution, with a filesystem fallback index
  Apps.qml          Pinned + running apps, merged into the dock model
  Settings*.qml     Settings window and its controls
bin/duck          CLI
install.sh        Symlinks, keybinding, autostart, window rule
```

## Notes

Two things behave differently than you might expect, both for good reasons:

- **Reordering uses `SHIFT`+arrows, not `SUPER`+arrows.** While the dock holds the
  keyboard, Hyprland still claims `SUPER`+arrows for window focus and intercepts
  them before the dock ever sees them.
- **Icons are resolved against a filesystem index, not just the icon theme.** Qt's
  themed lookup misses icons that live only in the `hicolor` fallback theme —
  Ghostty is one — so `Icons.qml` keeps its own index as a fallback.
