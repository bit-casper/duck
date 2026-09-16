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

Duck also adds itself to the Omarchy menu, so `SUPER+SPACE` → "duck" finds it.

### What it touches

| Path | What |
|---|---|
| `~/.config/quickshell/duck` | symlink to `shell/` |
| `~/.local/bin/duck` | symlink to `bin/duck` |
| `~/.config/hypr/duck.lua` | Duck's Hyprland config — keys, window rule, autostart |
| `~/.config/hypr/hyprland.lua` | one `require` line, between markers |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | Duck's menu rows, between markers |
| `~/.config/duck/config.json` | settings |

Hyprland has no drop-in directory for user config and the Omarchy menu reads one
fixed path, so those two shared files have to be edited. Duck writes only between
`>>> duck: begin` / `<<< duck: end` markers and keeps one `.duck-backup` per file.

`./uninstall.sh` removes all of it. It deletes only the text between its own
markers rather than restoring the backup, so anything you or Omarchy changed in
those files meanwhile is preserved. `--purge` also removes your settings.

## Using it

The dock stays hidden until you ask for it:

| Action | Result |
|---|---|
| Move the mouse to the bottom edge | Dock slides up |
| `SUPER+CTRL+DOWN` | Open the dock — and close it again |
| `SUPER+CTRL+LEFT` / `RIGHT` | Move the selection |
| `SUPER+CTRL+UP` | Launch the selected app, or focus it if running |

One modifier for everything, so navigating never breaks your hand position.

Duck never takes a keyboard grab, so the rest of the desktop keeps working while
the dock is open — you can carry on typing into whatever window is focused.

`SUPER+CTRL+LEFT/RIGHT` are Omarchy's grouped-window focus. Duck borrows them
only while the dock is on screen; with the dock down it hands the keypress back
to group focus, so that binding still does what it always did.

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
| `revealDelay` | `90` | ms of edge hover before revealing |
| `hideDelay` | `350` | ms after leaving before hiding |
| `animate` | `true` | Slide and hover transitions |

## Theming

Everything visual comes from Omarchy, live:

- `colors.toml` — the palette
- `shell.toml` — the same control fills, borders, type scale and spacing Omarchy
  styles its own bar and menus with
- Hyprland's `border_size`, `rounding` and `gaps_out` — so a bordered dock sits
  exactly where a window would, with the same border
- fontconfig — the system monospace family

Run `omarchy theme set <name>` or `omarchy font set <name>` and the dock follows
without a restart.

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
hypr/duck.lua     Hyprland config Duck installs (keys, window rule, autostart)
lib/              Marker-block helpers shared by install and uninstall
install.sh        Symlinks and config blocks
uninstall.sh      Removes all of it
```

## Notes

Several things behave differently than you might expect, each for a reason:

- **Keys are Super combinations, not bare arrows.** Capturing bare arrows needs
  either a keyboard grab (which routes every keystroke to the dock and makes the
  desktop feel frozen) or a Hyprland submap. On Hyprland 0.56 a submap collapses
  every binding onto the last one registered, so all its keys do the same thing.
  Ordinary global bindings on Super combinations are the one mechanism that works
  and takes nothing away from applications.
- **Duck gives `SUPER+CTRL+LEFT/RIGHT` back when it is not using them.** Rather
  than quietly claiming Omarchy's grouped-window focus, the handler forwards the
  keypress to `group.prev` / `group.next` whenever the dock is closed.
- **Reordering from the keyboard is unbound** for the same reason. Drag an icon,
  or use the arrows in the settings window. `hypr/duck.lua` has commented-out
  bindings if you want them on a Super combination.
- **Icon size is derived, not configured.** It follows the theme's type scale, in
  logical pixels — so the compositor scales it by your display scaling too.
- **Icons are resolved against a filesystem index, not just the icon theme.** Qt's
  themed lookup misses icons that live only in the `hicolor` fallback theme —
  Ghostty is one — so `Icons.qml` keeps its own index as a fallback.
- **Fonts follow fontconfig**, resolved with `fc-match` exactly as Omarchy's shell
  does, and `~/.config/fontconfig/fonts.conf` is watched so `omarchy font set`
  repaints Duck without a restart.
