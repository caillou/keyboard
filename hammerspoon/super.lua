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

  local keycode = event:getKeyCode()

  if keycode == 49 then -- 49 == space
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

  local keycode = event:getKeyCode()

  if state.isActive then
    if keycode == 49 then return true end -- 49 == space
    return
  end

  if keycode == 49 then  -- 49 == space
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

  local keycode = event:getKeyCode()

  if keycode == 49 then  -- 49 == space

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

  local keycode = event:getKeyCode()
  local mappedKey = keyMap[hs.keycodes.map[keycode]]

  if mappedKey then

    hs.eventtap.keyStroke(modifiers(event), mappedKey, 0)

    state.wasUsed = true
    return true
  end

end):start()


local superDuperModeAppMappings = {
  -- b = 'Google Chrome',
  -- c = 'Slack',
  -- e = 'Visual Studio Code',
  -- f = 'Finder',
  -- s = 'Spotify',
  -- t = 'iTerm',
  -- n = 'Notes',
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
  v = function ()
    hs.eventtap.keyStroke({'control', 'option'}, 'v', 0)
  end,
  d = function (event)
    -- (
    hs.eventtap.keyStroke({'shift'}, '9', 0)
  end,
  f = function (event)
    -- )
    hs.eventtap.keyStroke({'shift'}, '0', 0)
  end,
  e = function (event)
    -- {
    hs.eventtap.keyStroke({'shift'}, '[', 0)
  end,
  r = function (event)
    -- }
    hs.eventtap.keyStroke({'shift'}, ']', 0)
  end,
  x = function (event)
    --
    hs.eventtap.keyStroke({}, '[', 0)
  end,
  c = function (event)
    --
    hs.eventtap.keyStroke({}, ']', 0)
  end,
  h = function (event)
    --
    hs.eventtap.keyStroke({}, 'delete', 0)
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
    app(event)
  end

  state.wasUsed = true
  return true

end):start()

superDuperModeNavigationTraining = eventtap.new({ eventTypes.keyDown }, function(event)
  if not state.training or state.isActive then return end

  local keycode = event:getKeyCode()

  local isDelete = keycode == 51
  local isArrow = keycode <= 126 and keycode >= 123

  if isArrow or isDelete then -- the arrow keys
    hs.alert.show("Nope!")
    return true
  end
end):start()

-- local leftShift = false
-- local rightShift = false

-- local leftHandKeycode = function (keycode)
--   return (keycode >= 0 and keycode <= 3) or (keycode >= 5 and keycode <= 9) or
--   (keycode >= 18 and keycode <= 21) or (keycode >= 12 and keycode <= 15) or
--   (keycode == 17) or (keycode == 23) or
--   (keycode == 50)
-- end

-- superDuperModeTouchTypingTraining = eventtap.new({ eventTypes.keyDown }, function(event)
--   -- if not state.training or state.isActive then return end
--   if not state.leftShift and not state.rightShift then
--     return
--   end

--   local keycode = event:getKeyCode()
--   local isLeftKey = leftHandKeycode(keycode)

--   if state.leftShift and isLeftKey then
--     hs.alert.show("Nope!")
--     return true
--   end

--   -- if keycode <= 126 and keycode >= 123 then -- the arrow keys
--   --   hs.alert.show("Nope!")
--   --   return true
--   -- end
-- end):start()

-- local right_shift_handler = function(evt)
--   if not evt:getFlags()['shift'] then
--     state.leftShift = false
--     state.rightShift = false
--     return
--   end
--   local keycode = evt:getKeyCode()
--   logger:e(keycode)
--   if keycode == 56 then
--     state.leftShift = true
--     state.rightShift = false
--     return
--   end
--   if keycode == 60 then
--     state.leftShift = false
--     state.rightShift = true
--     return
--   end

-- end

-- local right_shift_tap = hs.eventtap.new({hs.eventtap.event.types.flagsChanged}, right_shift_handler)
-- right_shift_tap:start()

-- -- -- local rightAlphas = {
-- -- --   ~ = true,
-- -- --   ! = true,
-- -- --   @ = true,
-- -- --   # = true,
-- -- --   $ = true,
-- -- --   % = true,
-- -- --   Q = true,
-- -- --   W = true,
-- -- --   E = true,
-- -- --   R = true,
-- -- --   T = true,
-- -- --   A = true,
-- -- --   S = true,
-- -- --   D = true,
-- -- --   F = true,
-- -- --   G = true,
-- -- --   Z = true,
-- -- --   X = true,
-- -- --   C = true,
-- -- --   V = true,
-- -- -- }
