-- Install the `hs` CLI tool into ~/.local — XDG path, no sudo needed. Lets the
-- config be reloaded/inspected from a terminal: `hs -c "hs.reload()"`.
-- cliInstall refuses to repair a half-installed state: if
-- `hs.ipc.cliStatus(os.getenv('HOME') .. '/.local')` returns false even though
-- `hs -c "1+1"` works, run `hs.ipc.cliUninstall(...)` then reload — do not just
-- re-run cliInstall.
require("hs.ipc")
hs.ipc.cliInstall(os.getenv("HOME") .. "/.local")

-- Generate EmmyLua annotation stubs for hs.* editor autocomplete (dev tooling).
-- The generator runs as a side effect of the Spoon's :init(); a missing Spoon
-- is a no-op. Loaded before the pathwatchers below so its generated files don't
-- race the reload watcher.
pcall(hs.loadSpoon, "EmmyLua")

-- Use Shift+Control+` to reload Hammerspoon config
hs.hotkey.bind({ "shift", "ctrl" }, "`", nil, function()
  hs.reload()
end)

-- Auto-reload when any .lua file changes. FSEvents doesn't follow symlinks,
-- so we watch both ~/.hammerspoon/ and the resolved target of the keyboard/ symlink.
-- Generated EmmyLua annotation files (under an EmmyLua.spoon/annotations/ dir)
-- are ignored so stub generation never triggers a reload.
local function reloadOnLua(files)
  for _, file in ipairs(files) do
    if file:sub(-4) == ".lua" and not file:find("EmmyLua%.spoon/annotations/") then
      hs.reload()
      return
    end
  end
end

-- global on purpose: local would be GC'd and stop the watcher
configWatcher = hs.pathwatcher.new(hs.configdir, reloadOnLua):start()

local keyboardDir = hs.fs.pathToAbsolute(hs.configdir .. "/keyboard")
if keyboardDir and keyboardDir ~= hs.configdir .. "/keyboard" then
  keyboardWatcher = hs.pathwatcher.new(keyboardDir, reloadOnLua):start()
end

require("keyboard.windows")
require("keyboard.space-fn").start()

hs.notify
  .new({
    title = "Hammerspoon",
    informativeText = "Ready to rock 🤘",
  })
  :send()
