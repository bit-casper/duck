# Duck

A dock for [Omarchy](https://omarchy.org/). Hidden by default, slides up from the
bottom edge, themed from whatever Omarchy theme is active.

Duck is an Omarchy **shell plugin**: it loads into the same Quickshell process as
the bar and draws real `wlr-layer-shell` surfaces, so it uses Omarchy's own
colours, type scale, spacing and UI components rather than imitating them.

## Install

```bash
omarchy plugin add https://github.com/bit-casper/duck.git --enable
duck add ghostty chromium
```

That is the whole installation. There is no setup script to remember and none
to forget: everything Duck needs outside its own directory is set up when the
plugin loads and taken back down when it unloads.

## Uninstall

```bash
omarchy plugin remove io.github.bit-casper.duck
```

Also the whole of it, and in any order you like, because there is no second
step. `omarchy plugin remove` disables a plugin before deleting it, so Duck is
still loaded at that moment and undoes its own setup on the way out.

Your settings are deliberately left at `~/.config/duck/`, so reinstalling
restores your dock. Delete that directory if you want them gone.

### What it touches

`omarchy plugin add` owns `~/.config/omarchy/plugins/io.github.bit-casper.duck/`.
Outside that, while Duck is loaded:

| Path | What | Removed on unload |
|---|---|---|
| `~/.local/bin/duck` | symlink to the plugin's `bin/duck` | yes |
| `~/.config/omarchy/extensions/omarchy-menu.jsonc` | Duck's menu rows, between markers | yes |
| `~/.config/duck/config.json` | settings | no — yours to keep |

**Nothing is written to the Hyprland config.** The keybindings and the settings
window rule are registered with the running compositor through `hyprctl eval`
and revoked on unload. A binding made that way lives only in the running
Hyprland, so even a shell killed outright leaves nothing behind — the next
`hyprctl reload` erases it.

That is the point rather than a detail. Duck borrows `Super+Ctrl+Left/Right`
from Omarchy's grouped-window focus, and a binding file left behind by a removed
plugin would keep those keys captured — dead, with nothing on screen to say why.
Versions through 1.0 did install such a file; Duck removes it when it finds one,
keeping a copy at `duck.lua.duck-backup`.

The Omarchy menu is the one file Duck still edits, because the shell reads it
from a single fixed path with no drop-in beside it. Duck writes only between
`>>> duck: begin` / `<<< duck: end` markers, so whatever else is in there is
left alone, and it takes the block out again when it unloads.

Anything at `~/.local/bin/duck` that is not a symlink is left strictly alone —
Duck will report it and go without the CLI rather than move your file aside.

## Using it

The dock stays hidden until you ask for it:

| Action | Result |
|---|---|
| Move the mouse to the bottom edge | The dock slides up |
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
DuckKeys.qml      Bindings and window rule, registered at runtime
DuckCli.qml       The `duck` symlink in ~/.local/bin
DuckMenu.qml      Duck's rows in the Omarchy menu
blocks.js         Marker-block helpers for the files Duck shares with you
Settings.qml      Settings window, built from Omarchy's Ui components
bin/duck          CLI
```

Nothing here is a QML singleton: Omarchy's plugins do not use them, and state is
handed down from `Duck.qml` explicitly.

## Requirements

Omarchy (Quattro or later) with its Quickshell-based shell — Duck loads as a
shell plugin and uses `qs.Commons` and `qs.Ui`.

It shells out to a few things already present on an Omarchy system:

| Command | Used for |
|---|---|
| `hyprctl` | registering bindings and the window rule, reading `border_size` / `gaps_out`, and grouped-window focus forwarding |
| `sh` | the short one-liners below, so their arguments are passed rather than interpolated |
| `mkdir`, `ln`, `readlink`, `rm`, `cp`, `dirname`, `printf` | making and unmaking the CLI symlink, creating `~/.config/duck`, and backing up the Hyprland file older versions installed |
| `find` | building the icon index that covers `hicolor`-only icons |
| `python3` | the `duck` CLI |
| `omarchy-shell` | how the CLI talks to the plugin |
| `omarchy-launch-tui` | launching apps whose desktop entry sets `Terminal=true` |

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
  or use the arrows in the settings window. If you want keys for it, fill in
  `moveprev` / `movenext` under `keys` in `config.json` — every binding Duck
  registers is named there, and changing one takes effect without a restart.
- **Icon size is derived, not configured.** It follows the theme's type scale, in
  logical pixels — so the compositor scales it by your display scaling too.
- **Icons are resolved against a filesystem index, not just the icon theme.** Qt's
  themed lookup misses icons that live only in the `hicolor` fallback theme —
  Ghostty is one — so `Icons.qml` keeps its own index as a fallback.
- **Fonts come from the shell, not from Duck.** `Style.font` is already resolved
  against fontconfig by Omarchy, so reading it through `qs.Commons` means
  `omarchy font set` repaints Duck without a restart and without Duck running
  any font lookup of its own.
