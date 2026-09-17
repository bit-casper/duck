#!/usr/bin/env bash
#
# Sets up the parts of Duck that an Omarchy plugin cannot ship itself.
#
# The dock is installed by `omarchy plugin add`; what is left over is the
# Hyprland side (bindings and a window rule), the menu entry, and the CLI.
#
# Footprint, in full:
#   ~/.local/bin/duck           symlink to this plugin's bin/duck
#   omarchy-menu.jsonc          Duck's menu rows, between BEGIN/END markers
#
# Nothing is written to the Hyprland config. Bindings and the settings window
# rule are registered with the running compositor by the plugin itself, so they
# exist only while Duck is loaded.
#
# ./uninstall.sh removes every one of them. What it deliberately leaves behind
# is content that was never Duck's: a duck already sitting in ~/.local/bin is
# moved aside to duck.bak.<timestamp> rather than overwritten, and the
# .duck-backup of a file edited between markers is kept whenever it still
# differs from the live file. Uninstall reports both instead of deleting them.
# The one action taken beyond these paths is restarting the Omarchy shell, and
# only when it is found to be running older plugin code than what is on disk.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
HYPR_DIR="$HOME/.config/hypr"
MENU_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions/omarchy-menu.jsonc"

# The id the shell knows this plugin by; `omarchy plugin` matches it exactly.
PLUGIN_ID="$(sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$REPO/manifest.json" | head -1)"
PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"

# shellcheck source=lib/config-blocks.sh
source "$REPO/lib/config-blocks.sh"

say() { printf '  %s\n' "$*"; }

link() {
  local src="$1" dest="$2"

  if [[ -L "$dest" ]]; then
    if [[ "$(readlink -f "$dest" || true)" == "$(readlink -f "$src")" ]]; then
      say "ok       $dest"
      return
    fi
    rm "$dest"
  elif [[ -e "$dest" ]]; then
    mv "$dest" "$dest.bak.$(date +%s)"
    say "backed up $dest"
  fi

  ln -s "$src" "$dest"
  say "linked   $dest"
}

echo "Setting up Duck from $REPO"
# The plugin creates its own config directory, so setup.sh no longer needs to.
mkdir -p "$BIN_DIR"

link "$REPO/bin/duck" "$BIN_DIR/duck"

# Duck no longer writes anything into the Hyprland config. The plugin registers
# its bindings and its window rule with the running compositor at load, through
# `hyprctl eval`, so there is nothing here for a removed plugin to leave behind.
#
# Two earlier shapes did write, and both are taken back out — including on a
# machine that never runs uninstall.sh, because setup.sh is what a reinstall or
# an update runs.
for file in bindings.lua autostart.lua hyprland.lua; do
  if [[ -f "$HYPR_DIR/$file" ]] && hypr_has_legacy "$HYPR_DIR/$file"; then
    hypr_strip_legacy "$HYPR_DIR/$file"
    say "migrated $file (removed Duck's old inline block)"
  fi
done

if hypr_has_block "$HYPR_DIR/hyprland.lua"; then
  hypr_remove_block "$HYPR_DIR/hyprland.lua"
  say "migrated hyprland.lua (dropped Duck's require line)"
fi

# duck.lua was documented as yours to edit, so it is backed up rather than just
# deleted -- the keys it binds are Duck's own defaults now.
if [[ -f "$HYPR_DIR/duck.lua" ]]; then
  _hypr_backup "$HYPR_DIR/duck.lua"
  rm "$HYPR_DIR/duck.lua"
  say "migrated removed duck.lua (bindings are registered at runtime now)"
  say "         a copy is kept at duck.lua.duck-backup"
fi

# Adds a searchable "Duck" entry to the Omarchy menu (Super+Space).
if menu_has_block "$MENU_FILE"; then
  say "ok       Omarchy menu already has Duck"
elif [[ -d "$(dirname "$MENU_FILE")" ]]; then
  menu_add_block "$MENU_FILE"
  say "updated  Omarchy menu (Super+Space -> search \"Duck\")"
else
  say "skipped  Omarchy menu (no extensions directory)"
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
  errors="$(hyprctl configerrors 2>/dev/null || true)"
  if [[ -n "$errors" && "$errors" != "no errors" ]]; then
    echo
    echo "Hyprland reported config errors:"
    echo "$errors"
    exit 1
  fi
fi

# The plugin side. `omarchy plugin add` loads the dock itself, so a fresh
# install needs nothing here. The case worth handling is a shell that was
# already running when the plugin directory was replaced — reinstalling, or
# checking out another branch in it, leaves the file watcher on the deleted
# inode, and the shell goes on rendering the QML it loaded at startup.
#
# Restarting every time would drop the bar on runs that do not need it, so
# look first: /proc/<pid> is stamped when the process starts, which dates the
# code it is running against the files it was meant to load.

shell_pid() {
  local pid
  for pid in $(pgrep -x quickshell 2>/dev/null); do
    if tr '\0' ' ' <"/proc/$pid/cmdline" 2>/dev/null | grep -q "omarchy/shell"; then
      printf '%s\n' "$pid"
      return 0
    fi
  done
  return 1
}

shell_is_stale() {
  local pid
  [[ -n "$PLUGIN_ID" && -d "$PLUGIN_DIR" ]] || return 1
  pid="$(shell_pid)" || return 1
  [[ -n "$(find "$PLUGIN_DIR" -maxdepth 1 -name '*.qml' -newer "/proc/$pid" -print -quit 2>/dev/null)" ]]
}

if command -v omarchy >/dev/null 2>&1 && shell_is_stale; then
  if omarchy restart shell >/dev/null 2>&1; then
    say "restarted omarchy-shell (it was running older plugin code)"
  else
    say "stale    omarchy-shell is running older plugin code; run: omarchy restart shell"
  fi
fi

echo
echo "Ready. Next:"
echo "  duck add ghostty      # pin an app"
echo "  SUPER+CTRL+DOWN       # raise the dock"
echo
echo "If the dock is not showing, enable the plugin:"
echo "  omarchy plugin enable ${PLUGIN_ID:-io.github.bit-casper.duck}"
