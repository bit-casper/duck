# Duck

A dock for [Omarchy](https://omarchy.org/). Hidden by default, slides up from the
bottom edge, themed from whatever Omarchy theme is active.

Duck is an Omarchy **shell plugin**: it loads into the same Quickshell process as
the bar and draws real `wlr-layer-shell` surfaces, so it uses Omarchy's own
colours, type scale, spacing and UI components rather than imitating them.

## Install

```bash
omarchy plugin add https://github.com/bit-casper/duck.git --enable
~/.config/omarchy/plugins/io.github.bit-casper.duck/setup.sh
duck add ghostty chromium
```

The first command installs the dock. The second sets up the parts a plugin
cannot ship itself — the Hyprland bindings, the Omarchy menu entry, and the
`duck` CLI.

### What it touches

`omarchy plugin add` owns `~/.config/omarchy/plugins/io.github.bit-casper.duck/`,
and `omarchy plugin remove io.github.bit-casper.duck` takes it away again. `setup.sh` adds:

| Path | What |
|---|---|
| `~/.local/bin/duck` | symlink to the plugin's `bin/duck` |
| `~/.config/hypr/duck.lua` | Duck's Hyprland config — bindings and a window rule |
| `~/.config/hypr/hyprland.lua` | one `require` line, between markers |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | Duck's menu rows, between markers |
| `~/.config/duck/config.json` | settings |

Hyprland has no drop-in directory for user config and the Omarchy menu reads one
fixed path, so those two shared files have to be edited. Duck writes only between
`>>> duck: begin` / `<<< duck: end` markers and keeps one `.duck-backup` per file.

`./uninstall.sh` reverses `setup.sh`. It deletes only the text between its own
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

duck enable | disable | restart | status
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

Duck uses Omarchy's own `qs.Commons` — `Style`, `Color` and `Border` — so it is
themed by the same values as the bar and menus, not by a copy of them. Fonts,
the type scale, control fills, borders and corner radius all come straight from
there, and `omarchy theme set <name>` or `omarchy font set <name>` restyles the
dock along with everything else.

The one exception is `DuckHypr.qml`, which reads Hyprland's `general:border_size`
and `general:gaps_out` directly, because `Style` exposes neither at full
precision — and a bordered dock has to sit exactly where a window would.

## Layout

```
manifest.json     Omarchy plugin manifest (kind: panel)
Duck.qml          Plugin entry point: owns state, docks, shortcuts and IPC
Dock.qml          The layer-shell panel: reveal, drag-reorder, pointer handling
DockItem.qml      A single icon
DuckConfig.qml    config.json, watched and hot-reloaded
DuckApps.qml      Pinned + running apps, merged into the dock model
DuckIcons.qml     Icon resolution, with a filesystem fallback index
DuckHypr.qml      The two Hyprland values Omarchy's Style does not expose
Settings.qml      Settings window, built from Omarchy's Ui components
bin/duck          CLI
hypr/duck.lua     Hyprland bindings and window rule
lib/              Marker-block helpers shared by setup and uninstall
setup.sh          Keys, menu entry and CLI (what a plugin cannot ship)
uninstall.sh      Reverses setup.sh
```

Nothing here is a QML singleton: Omarchy's plugins do not use them, and state is
handed down from `Duck.qml` explicitly.

## Requirements

Omarchy (Quattro or later) with its Quickshell-based shell — Duck loads as a
shell plugin and uses `qs.Commons` and `qs.Ui`.

It shells out to a few things already present on an Omarchy system:

| Command | Used for |
|---|---|
| `hyprctl` | reading `border_size` / `gaps_out`, and grouped-window focus forwarding |
| `fc-match` | resolving the system monospace font |
| `find` | building the icon index that covers `hicolor`-only icons |
| `python3` | the `duck` CLI |
| `omarchy-shell` | how the CLI talks to the plugin |

No other external dependencies, no network access, and nothing is downloaded at
runtime.

## License

[MIT](LICENSE) © Casper Frost

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
