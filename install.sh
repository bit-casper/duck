#!/usr/bin/env bash
#
# Installs Duck for the current user.
#
# Footprint, in full:
#   ~/.config/quickshell/duck   symlink to this repo's shell/
#   ~/.local/bin/duck           symlink to this repo's bin/duck
#   ~/.config/hypr/duck.lua     Duck's Hyprland config (keybinding, rules, autostart)
#   ~/.config/hypr/hyprland.lua one `require` line between BEGIN/END markers
#   omarchy-menu.jsonc          Duck's menu rows, between BEGIN/END markers
#   ~/.config/duck/config.json  settings
#
# ./uninstall.sh removes every one of them. Nothing else is modified.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
BIN_DIR="$HOME/.local/bin"
HYPR_DIR="$HOME/.config/hypr"
MENU_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions/omarchy-menu.jsonc"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/duck"

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

echo "Installing Duck from $REPO"
mkdir -p "$QS_DIR" "$BIN_DIR" "$HYPR_DIR" "$CONF_DIR"

link "$REPO/shell" "$QS_DIR/duck"
link "$REPO/bin/duck" "$BIN_DIR/duck"

# Earlier versions appended separate blocks to three different files. Fold them
# into the single owned file so an uninstall has one thing to undo.
migrated=0
for file in bindings.lua autostart.lua hyprland.lua; do
  if [[ -f "$HYPR_DIR/$file" ]] && hypr_has_legacy "$HYPR_DIR/$file"; then
    hypr_strip_legacy "$HYPR_DIR/$file"
    say "migrated $file (removed Duck's old inline block)"
    migrated=1
  fi
done
[[ $migrated -eq 1 ]] && say "         Duck's Hyprland config now lives in hypr/duck.lua"

if [[ -f "$HYPR_DIR/duck.lua" ]]; then
  say "kept     $HYPR_DIR/duck.lua (yours; not overwritten)"
else
  cp "$REPO/hypr/duck.lua" "$HYPR_DIR/duck.lua"
  say "created  $HYPR_DIR/duck.lua"
fi

if hypr_has_block "$HYPR_DIR/hyprland.lua"; then
  say "ok       hyprland.lua already loads Duck"
else
  hypr_add_block "$HYPR_DIR/hyprland.lua"
  say "updated  hyprland.lua (one require line, between markers)"
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

if [[ -f "$CONF_DIR/config.json" ]]; then
  say "kept     $CONF_DIR/config.json"
else
  cat >"$CONF_DIR/config.json" <<'JSON'
{
  "apps": [],
  "showRunning": true,
  "bordered": true,
  "pushWindows": false,
  "edgeReveal": true,
  "revealDelay": 90,
  "hideDelay": 350,
  "animate": true
}
JSON
  say "created  $CONF_DIR/config.json"
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

echo
echo "Installed. Next:"
echo "  duck add ghostty      # pin an app"
echo "  duck start            # run the dock"
echo "  SUPER+CTRL+DOWN       # raise it"
