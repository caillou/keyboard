local eventtap = hs.eventtap
local eventTypes = hs.eventtap.event.types

local logger = hs.logger.new('super')

local state = {}
state.isActive = false
state.outputNextSpace = false
state.isTyping = false
state.training = true

local modifiers = function (event)
  local modifiers = {}
  -- Apply the standard modifier keys that are active (if any)
  for k, v in pairs(event:getFlags()) do
    table.insert(modifiers, k)
  end
  return modifiers
end

local typingTimer

superDuperModeTyping = eventtap.new({ eventTypes.keyDown }, function(event)
  if state.isActive then
    return
  end

  local keyCode = event:getKeyCode()

  if keyCode == 49 then -- 49 == space
    return
  end

  state.isTyping = true

  if typingTimer then
    typingTimer:stop()
  end

  typingTimer = hs.timer.doAfter(0.3, function()
    state.isTyping = false
  end)
end):start()

local wasUsedTimer

superDuperModeActivationListener = eventtap.new({ eventTypes.keyDown }, function(event)

  if state.isTyping then
    return
  end

  local keyCode = event:getKeyCode()

  if state.isActive then
    if keyCode == 49 then return true end -- 49 == space
    return
  end

  if keyCode == 49 then  -- 49 == space
    if not state.outputNextSpace then

      -- We are now in the SuperDuperMode
      state.isActive = true
      state.wasUsed = false

      -- If we hold space for a while without using it, we don't
      -- want to output a space.
      if typingTimer then typingTimer:stop() end
      typingTimer = hs.timer.doAfter(0.4, function()
        state.wasUsed = true
      end)

      return true

    else
      state.outputNextSpace = false
    end
  end

end):start()

superDuperModeDeactivationListener = eventtap.new({ eventTypes.keyUp }, function(event)
  if not state.isActive then
    return
  end

  local keyCode = event:getKeyCode()

  if keyCode == 49 then  -- 49 == space

    state.isActive = false

    if not state.wasUsed then
      state.outputNextSpace = true
      hs.timer.doAfter(0, function ()
        hs.eventtap.keyStroke(modifiers(event), 'space', 0)
      end)
    end

    return
  end

end):start()

local keyMap = {
  i = 'up', -- 34
  j = 'left', -- 38
  k = 'down', -- 40
  l = 'right', -- 37
}

superDuperModeNavigation = eventtap.new({ eventTypes.keyDown }, function(event)

  if not state.isActive then
    return
  end

  local keyCode = event:getKeyCode()
  local mappedKey = keyMap[hs.keycodes.map[keyCode]]

  if mappedKey then

    hs.eventtap.keyStroke(modifiers(event), mappedKey, 0)

    state.wasUsed = true
    return true
  end

end):start()


local superDuperModeAppMappings = {
  b = 'Google Chrome',
  c = 'Slack',
  e = 'Visual Studio Code',
  f = 'Finder',
  s = 'Spotify',
  t = 'iTerm',
  a = function ()
    state.training = not state.training
  end,
  u = function ()
    -- Go to previous tab in most apps
    hs.eventtap.keyStroke({'cmd', 'shift'}, '[', 0)
  end,
  o = function ()
    -- Go to next tab in most apps
    hs.eventtap.keyStroke({'cmd', 'shift'}, ']', 0)
  end,
}

superDuperModeApplicationSwitcher = eventtap.new({ eventTypes.keyDown }, function(event)

  if not state.isActive then
    return
  end

  local character = event:getCharacters()
  local app = superDuperModeAppMappings[character]

  if not app then
    return
  end

  if (type(app) == 'string') then
    local frontmostApp = hs.application.frontmostApplication()
    local openApp = hs.application.get(app)
    if openApp and frontmostApp:name() == openApp:name() then
      hs.eventtap.keyStroke({'command'}, '`', 0)
    else
      hs.application.open(app)
    end
  elseif (type(app) == 'function') then
    app()
  end

  state.wasUsed = true
  return true

end):start()

superDuperModeNavigationTraining = eventtap.new({ eventTypes.keyDown }, function(event)
  if not state.training or state.isActive then return end

  local keycode = event:getKeyCode()

  if keycode <= 126 and keycode >= 123 then -- the arrow keys
    hs.alert.show("Nope!")
    return true
  end
end):start()
