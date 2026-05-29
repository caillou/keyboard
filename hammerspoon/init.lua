local log = hs.logger.new('init.lua', 'debug')

-- Enable the `hs` CLI tool so config can be reloaded / inspected from a terminal.
-- cliInstall() is a no-op if already installed; first install prompts for admin auth.
require('hs.ipc')
hs.ipc.cliInstall()

-- Use Shift+Control+` to reload Hammerspoon config
hs.hotkey.bind({'shift','ctrl'}, '`', nil, function()
  hs.reload()
end)

-- Auto-reload when any .lua file under ~/.hammerspoon/ (incl. the keyboard/ symlink) changes.
configWatcher = hs.pathwatcher.new(hs.configdir, function(files)
  for _, file in ipairs(files) do
    if file:sub(-4) == '.lua' then
      hs.reload()
      return
    end
  end
end):start()

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
