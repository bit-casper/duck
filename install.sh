#!/usr/bin/env bash
#
# Installs Duck for the current user.
#
# Everything is symlinked back to this repo, so editing the source here takes
# effect immediately — Quickshell hot-reloads the QML on save.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
QS_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
BIN_DIR="$HOME/.local/bin"
HYPR_DIR="$HOME/.config/hypr"
BINDING_KEY="SUPER + CTRL + DOWN"

say() { printf '  %s\n' "$*"; }

link() {
  local src="$1" dest="$2"

  if [[ -L "$dest" ]]; then
    local current
    current="$(readlink -f "$dest" || true)"
    [[ "$current" == "$(readlink -f "$src")" ]] && { say "ok      $dest"; return; }
    rm "$dest"
  elif [[ -e "$dest" ]]; then
    mv "$dest" "$dest.bak.$(date +%s)"
    say "backed up existing $dest"
  fi

  ln -s "$src" "$dest"
  say "linked  $dest -> $src"
}

# Appends a block to a Hyprland Lua config, but only once.
append_once() {
  local file="$1" marker="$2" block="$3"

  [[ -f "$file" ]] || touch "$file"

  if grep -qF "$marker" "$file"; then
    say "ok      $file already configured"
    return
  fi

  cp "$file" "$file.bak.$(date +%s)"
  printf '\n%s\n' "$block" >>"$file"
  say "updated $file"
}

echo "Installing Duck from $REPO"

mkdir -p "$QS_DIR" "$BIN_DIR" "$HOME/.config/duck"

link "$REPO/shell" "$QS_DIR/duck"
link "$REPO/bin/duck" "$BIN_DIR/duck"

# Seed a config so the first launch has something to show.
if [[ ! -f "$HOME/.config/duck/config.json" ]]; then
  cat >"$HOME/.config/duck/config.json" <<'JSON'
{
  "apps": [],
  "showRunning": true,
  "bordered": true,
  "pushWindows": false,
  "iconSize": 44,
  "padding": 8,
  "gap": 10,
  "revealDelay": 90,
  "hideDelay": 350,
  "edgeReveal": true,
  "animate": true
}
JSON
  say "created ~/.config/duck/config.json"
fi

append_once "$HYPR_DIR/bindings.lua" "duck toggle" \
"-- Duck dock: raise the dock and take keyboard control.
o.bind(\"$BINDING_KEY\", \"Toggle Duck dock\", \"duck toggle\")"

append_once "$HYPR_DIR/autostart.lua" "qs -c duck" \
'-- Duck dock
o.launch_on_start("qs -c duck")'

# The settings window is an ordinary toplevel, so without a rule Hyprland tiles
# it into the current layout instead of showing it as a dialog.
append_once "$HYPR_DIR/hyprland.lua" "Duck Settings" \
'-- Duck: float the dock settings window.
o.window({ class = "^org\\.quickshell$", title = "^Duck Settings$" }, {
  float = true,
  center = true,
  size = { 520, 720 },
})'

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl reload >/dev/null 2>&1 || true
  errors="$(hyprctl configerrors 2>/dev/null || true)"
  if [[ -n "$errors" && "$errors" != "no errors" ]]; then
    echo
    echo "Hyprland reported config errors:"
    echo "$errors"
  fi
fi

echo
echo "Installed. Next:"
echo "  duck add ghostty        # pin an app"
echo "  duck start              # run the dock"
echo "  $BINDING_KEY   # raise it"
