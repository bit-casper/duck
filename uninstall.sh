#!/usr/bin/env bash
#
# Removes Duck, leaving the system as it was before install.sh ran.
#
# By default your settings (~/.config/duck) are kept, so reinstalling restores
# your dock. Pass --purge to remove those too.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$HOME/.local/bin"
HYPR_DIR="$HOME/.config/hypr"
MENU_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/extensions/omarchy-menu.jsonc"
CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/duck"

# shellcheck source=lib/config-blocks.sh
source "$REPO/lib/config-blocks.sh"

purge=0
[[ "${1:-}" == "--purge" ]] && purge=1

say() { printf '  %s\n' "$*"; }

# Only remove a symlink if it actually points into this repo — never touch
# something the user put there themselves.
unlink_ours() {
  local dest="$1" expect="$2"

  if [[ -L "$dest" && "$(readlink -f "$dest" || true)" == "$(readlink -f "$expect")" ]]; then
    rm "$dest"
    say "removed  $dest"
  elif [[ -e "$dest" ]]; then
    say "left     $dest (not ours)"
  fi
}

echo "Uninstalling Duck"

# The dock itself is removed with `omarchy plugin remove duck`; this undoes
# the configuration that plugin could not install on its own.
if command -v duck >/dev/null 2>&1; then
  duck hide >/dev/null 2>&1 || true
fi

unlink_ours "$BIN_DIR/duck" "$REPO/bin/duck"

# A duck already at that path when setup.sh ran was moved aside, not
# overwritten. It was never ours, so report where it went rather than deleting
# it or putting it back over something the user may since have chosen.
while IFS= read -r saved; do
  [[ -n "$saved" ]] || continue
  say "left     $saved (yours, moved aside at install)"
done < <(find "$BIN_DIR" -maxdepth 1 -name 'duck.bak.*' 2>/dev/null | sort || true)

if hypr_has_block "$HYPR_DIR/hyprland.lua"; then
  hypr_remove_block "$HYPR_DIR/hyprland.lua"
  say "removed  Duck's require line from hyprland.lua"
fi

# Older versions edited these directly; clean them up even when uninstalling
# from a newer checkout.
for file in bindings.lua autostart.lua hyprland.lua; do
  if [[ -f "$HYPR_DIR/$file" ]] && hypr_has_legacy "$HYPR_DIR/$file"; then
    hypr_strip_legacy "$HYPR_DIR/$file"
    say "removed  Duck's old inline block from $file"
  fi
done

if menu_has_block "$MENU_FILE"; then
  menu_remove_block "$MENU_FILE"
  say "removed  Duck's rows from the Omarchy menu"
fi

if [[ -f "$HYPR_DIR/duck.lua" ]]; then
  rm "$HYPR_DIR/duck.lua"
  say "removed  $HYPR_DIR/duck.lua"
fi

if [[ $purge -eq 1 ]]; then
  if [[ -d "$CONF_DIR" ]]; then
    rm -rf "$CONF_DIR"
    say "removed  $CONF_DIR"
  fi
else
  [[ -d "$CONF_DIR" ]] && say "kept     $CONF_DIR (use --purge to remove)"
fi

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
  errors="$(hyprctl configerrors 2>/dev/null || true)"
  if [[ -n "$errors" && "$errors" != "no errors" ]]; then
    echo
    echo "Hyprland reported config errors after cleanup:"
    echo "$errors"
  fi
fi

# Duck's own backups are ours to clean up. Remove one only when the live file
# already matches it -- if they differ, the user has edits worth keeping a
# safety net for, so it stays and is reported.
while IFS= read -r backup; do
  [[ -n "$backup" ]] || continue
  live="${backup%.duck-backup}"

  if [[ -f "$live" ]] && cmp -s "$backup" "$live"; then
    rm "$backup"
    say "removed  $backup (identical to current file)"
  else
    say "kept     $backup (differs from current file)"
  fi
done < <(find "$HYPR_DIR" "$(dirname "$MENU_FILE")" -maxdepth 1 -name '*.duck-backup' 2>/dev/null | sort || true)

echo
echo "Done. To remove the dock itself:"
echo "  omarchy plugin remove duck"
