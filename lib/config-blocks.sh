#!/usr/bin/env bash
#
# Shared helpers for the Omarchy menu block Duck owns, plus removal of the
# Hyprland edits earlier versions made and this one no longer does.
#
# Nothing here adds anything to the Hyprland config any more -- the plugin
# registers its bindings with the running compositor instead. What remains on
# that side is removal, which has to keep working for machines that still carry
# the old block.
#
# Every edit is delimited by markers so it can be removed exactly, without
# rewriting anything the user put there.

DUCK_BEGIN="-- >>> duck: begin (managed by duck/install.sh) >>>"
DUCK_END="-- <<< duck: end <<<"

# Keep exactly one backup per file, taken the first time Duck touches it, so
# that install/uninstall cycles cannot litter the config directory. The name is
# distinctive enough that uninstall can safely reclaim it.
_hypr_backup() {
  [[ -e "$1.duck-backup" ]] || cp "$1" "$1.duck-backup"
}

hypr_has_block() {
  [[ -f "$1" ]] && grep -qF -- "$DUCK_BEGIN" "$1"
}

hypr_remove_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  hypr_has_block "$file" || return 0
  _hypr_backup "$file"

  DUCK_BEGIN="$DUCK_BEGIN" DUCK_END="$DUCK_END" python3 - "$file" <<'PY'
import os, re, sys

path = sys.argv[1]
begin = re.escape(os.environ["DUCK_BEGIN"])
end = re.escape(os.environ["DUCK_END"])

text = open(path).read()
# Take the blank line before the block with it, so repeated install/uninstall
# cycles do not accumulate whitespace at the end of the file.
cleaned = re.sub(r"\n*" + begin + r".*?" + end + r"\n?", "\n", text, flags=re.S)
open(path, "w").write(cleaned.rstrip("\n") + "\n")
PY
}

# --- legacy: inline blocks from versions before hypr/duck.lua existed --------

_LEGACY_MARKERS=(
  "-- Duck dock: raise the dock and take keyboard control."
  "-- Duck dock"
  "-- Duck: float the dock settings window."
)

hypr_has_legacy() {
  local file="$1" marker
  [[ -f "$file" ]] || return 1
  for marker in "${_LEGACY_MARKERS[@]}"; do
    grep -qF -- "$marker" "$file" && return 0
  done
  return 1
}

hypr_strip_legacy() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  _hypr_backup "$file"

  python3 - "$file" <<'PY'
import re, sys

path = sys.argv[1]
text = open(path).read()

# Each legacy block is a Duck comment plus the statement that follows it: a
# single o.bind/o.launch_on_start line, or a balanced o.window({...}) call.
patterns = [
    r"\n*-- Duck dock: raise the dock and take keyboard control\.\n"
    r"o\.bind\([^\n]*\)\n",
    r"\n*-- Duck dock\n"
    r"o\.launch_on_start\([^\n]*\)\n",
    r"\n*-- Duck: float the dock settings window\.\n"
    r"o\.window\(.*?\n\}\)\n",
]

for pattern in patterns:
    text = re.sub(pattern, "\n", text, flags=re.S)

open(path, "w").write(text.rstrip("\n") + "\n")
PY
}

# --- Omarchy menu (~/.config/omarchy/extensions/omarchy-menu.jsonc) ----------
#
# The menu loader reads exactly one hardcoded path, so there is no drop-in
# directory to use; Duck's rows go into that shared user file between the same
# markers, and come back out on uninstall. JSONC allows comments and trailing
# commas, so the block is self-contained and needs no edits to its neighbours.

MENU_BEGIN="  // >>> duck: begin (managed by duck/install.sh) >>>"
MENU_END="  // <<< duck: end <<<"

menu_has_block() {
  [[ -f "$1" ]] && grep -qF -- "$MENU_BEGIN" "$1"
}

menu_add_block() {
  local file="$1"
  [[ -f "$file" ]] || printf '{\n}\n' >"$file"
  _hypr_backup "$file"

  MENU_BEGIN="$MENU_BEGIN" MENU_END="$MENU_END" python3 - "$file" <<'PY'
import os, sys

path = sys.argv[1]
text = open(path).read()

rows = [
    os.environ["MENU_BEGIN"],
    '  "duck": {"icon":"\U000f01e5","label":"Duck","description":"Dock settings and controls","aliases":["dock"]},',
    '  "duck.settings": {"icon":"\U000f0493","label":"Settings","action":"duck settings"},',
    '  "duck.toggle": {"icon":"","label":"Toggle dock","action":"duck toggle"},',
    '  "duck.restart": {"icon":"","label":"Restart dock","action":"duck restart"},',
    os.environ["MENU_END"],
]

# Insert just inside the object's closing brace, leaving everything above it
# untouched.
close = text.rindex("}")
before = text[:close].rstrip("\n")
after = text[close:]

open(path, "w").write(before + "\n" + "\n".join(rows) + "\n" + after)
PY
}

menu_remove_block() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  menu_has_block "$file" || return 0
  _hypr_backup "$file"

  MENU_BEGIN="$MENU_BEGIN" MENU_END="$MENU_END" python3 - "$file" <<'PY'
import os, re, sys

path = sys.argv[1]
begin = re.escape(os.environ["MENU_BEGIN"])
end = re.escape(os.environ["MENU_END"])

text = open(path).read()
open(path, "w").write(re.sub(begin + r".*?" + end + r"\n?", "", text, flags=re.S))
PY
}
