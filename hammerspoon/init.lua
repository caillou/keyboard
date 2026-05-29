local log = hs.logger.new('init.lua', 'debug')

-- Install the `hs` CLI tool into ~/.local — XDG path, no sudo needed. See CLAUDE.md.
require('hs.ipc')
hs.ipc.cliInstall(os.getenv('HOME') .. '/.local')

-- Use Shift+Control+` to reload Hammerspoon config
hs.hotkey.bind({'shift','ctrl'}, '`', nil, function()
  hs.reload()
end)

-- Auto-reload when any .lua file changes. FSEvents doesn't follow symlinks,
-- so we watch both ~/.hammerspoon/ and the resolved target of the keyboard/ symlink.
local function reloadOnLua(files)
  for _, file in ipairs(files) do
    if file:sub(-4) == '.lua' then
      hs.reload()
      return
    end
  end
end

-- global on purpose: local would be GC'd and stop the watcher
configWatcher = hs.pathwatcher.new(hs.configdir, reloadOnLua):start()

local keyboardDir = hs.fs.pathToAbsolute(hs.configdir .. '/keyboard')
if keyboardDir and keyboardDir ~= hs.configdir .. '/keyboard' then
  keyboardWatcher = hs.pathwatcher.new(keyboardDir, reloadOnLua):start()
end

keyUpDown = function(modifiers, key)
  -- Un-comment & reload config to log each keystroke that we're triggering
  -- log.d('Sending keystroke:', hs.inspect(modifiers), key)

  hs.eventtap.keyStroke(modifiers, key, 0)
end

-- Subscribe to the necessary events on the given window filter such that the
-- given hotkey is enabled for windows that match the window filter and disabled
-- for windows that don't match the window filter.
--
-- windowFilter - An hs.window.filter object describing the windows for which
--                the hotkey should be enabled.
-- hotkey       - The hs.hotkey object to enable/disable.
--
-- Returns nothing.
enableHotkeyForWindowsMatchingFilter = function(windowFilter, hotkey)
  windowFilter:subscribe(hs.window.filter.windowFocused, function()
    hotkey:enable()
  end)

  windowFilter:subscribe(hs.window.filter.windowUnfocused, function()
    hotkey:disable()
  end)
end

require('keyboard.windows')

hs.notify.new({
  title='Hammerspoon',
  informativeText='Ready to rock 🤘'
}):send()
