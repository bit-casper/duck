-- Duck dock — Hyprland configuration.
--
-- Installed to ~/.config/hypr/duck.lua and loaded by a single line in
-- hyprland.lua. This is the only Hyprland file Duck owns; ./uninstall.sh
-- removes it and that line, and touches nothing else.
--
-- Yours to edit — reinstalling keeps your changes rather than overwriting them.

-- Keyboard control.
--
-- Plain global bindings on Super combinations, not a submap and not a
-- layer-shell keyboard grab. A grab routes every keystroke to the dock and
-- leaves the desktop feeling frozen; Hyprland 0.56's Lua submaps collapse every
-- binding onto the last one registered. Super combinations are free, are never
-- typed into an application, and Duck ignores them while the dock is closed.
local function dock_key(name)
  return hl.dsp.global("duck:" .. name)
end

o.bind("SUPER + CTRL + DOWN", "Duck: open / close the dock", dock_key("toggle"))
o.bind("SUPER + CTRL + UP", "Duck: launch selected app", dock_key("activate"))

-- Super+Ctrl+Left/Right are Omarchy's grouped-window focus. Duck takes the
-- binding but only acts on it while the dock is open; the rest of the time it
-- forwards the keypress straight back to group focus, so nothing is lost.
hl.unbind("SUPER + CTRL + LEFT")
hl.unbind("SUPER + CTRL + RIGHT")
o.bind("SUPER + CTRL + LEFT", "Duck: select left (else group focus left)", dock_key("prev"))
o.bind("SUPER + CTRL + RIGHT", "Duck: select right (else group focus right)", dock_key("next"))

-- Reordering from the keyboard is left unbound: Super+Shift+Ctrl+Left/Right are
-- free if you want it, but dragging an icon or using the arrows in the settings
-- window covers the same ground without another modifier.
-- o.bind("SUPER + SHIFT + CTRL + LEFT", "Duck: move app left", dock_key("moveprev"))
-- o.bind("SUPER + SHIFT + CTRL + RIGHT", "Duck: move app right", dock_key("movenext"))

-- Closing also happens on Super+Ctrl+Down; this is here for a dedicated key.
-- o.bind("SUPER + SHIFT + CTRL + UP", "Duck: close", dock_key("hide"))

-- The settings window is an ordinary toplevel, so without this Hyprland tiles
-- it into the current layout instead of showing it as a dialog.
o.window({ class = "^org\\.quickshell$", title = "^Duck Settings$" }, {
  float = true,
  center = true,
  size = { 520, 720 },
})

-- Start the dock with the session.
o.launch_on_start("qs -c duck")
