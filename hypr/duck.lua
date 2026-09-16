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

o.bind("SUPER + CTRL + DOWN", "Duck: open / next app", dock_key("opennext"))
o.bind("SUPER + CTRL + UP", "Duck: previous app", dock_key("prev"))
o.bind("SUPER + SHIFT + CTRL + DOWN", "Duck: launch selected", dock_key("activate"))
o.bind("SUPER + SHIFT + CTRL + UP", "Duck: close", dock_key("hide"))

-- Reordering from the keyboard is left unbound. Hyprland 0.56 has no way to
-- capture bare arrow keys only while the dock is open -- a submap collapses
-- every binding onto the last one registered -- and binding bare arrows
-- globally would take them away from every application. Drag an icon instead,
-- or use the arrows in the settings window. Bind these if you want them anyway:
-- o.bind("SUPER + SHIFT + CTRL + LEFT", "Duck: move app left", dock_key("moveprev"))
-- o.bind("SUPER + SHIFT + CTRL + RIGHT", "Duck: move app right", dock_key("movenext"))

-- The settings window is an ordinary toplevel, so without this Hyprland tiles
-- it into the current layout instead of showing it as a dialog.
o.window({ class = "^org\\.quickshell$", title = "^Duck Settings$" }, {
  float = true,
  center = true,
  size = { 520, 720 },
})

-- Start the dock with the session.
o.launch_on_start("qs -c duck")
