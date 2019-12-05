-- -- A global variable for the Hyper Mode
-- hyper = hs.hotkey.modal.new({}, 'F17')

-- -- Enter Hyper Mode when F18 (Hyper/Capslock) is pressed
-- function enterHyperMode()
--   hyper.triggered = false
--   hyper:enter()
-- end

-- -- Leave Hyper Mode when F18 (Hyper/Capslock) is pressed,
-- -- send ESCAPE if no other keys are pressed.
-- function exitHyperMode()
--   hyper:exit()
--   hs.eventtap.keyStroke({}, 'space', 0)
-- end

-- -- Bind the Hyper key
-- f18 = hs.hotkey.bind({}, 'F18', enterHyperMode, exitHyperMode)

-- hyper:bind({}, 'j', function()
--   hs.eventtap.keyStroke({}, 'left', 0)
-- end)

local eventtap = hs.eventtap
local eventTypes = hs.eventtap.event.types

local keyMap = {
  i = 'up', -- 34
  j = 'left', -- 38
  k = 'down', -- 40
  l = 'right', -- 37
}

local state = {}
state.isActive = false

superDuperModeActivationListener = eventtap.new({ eventTypes.keyDown }, function(event)

  local kc = event:getKeyCode()
  -- hs.logger.new('hyper'):e(kc)

  if kc == 79 then -- f18 key
    state.isActive = true;
    return true
  end

  if not state.isActive then
    return
  end

  local mappedKey = keyMap[hs.keycodes.map[kc]]

  if mappedKey then
    local modifiers = {}
    -- Apply the standard modifier keys that are active (if any)
    for k, v in pairs(event:getFlags()) do
      table.insert(modifiers, k)
    end
    hs.eventtap.keyStroke(modifiers, mappedKey, 0)
    return true
  end

end):start()

superDuperModeDeactivationListener = eventtap.new({ eventTypes.keyUp }, function(event)

  if not state.isActive then
    return
  end

  local kc = event:getKeyCode()

  if kc == 79 then -- f18 key
    state.isActive = false;
    return true
  end

end):start()

-- --------------------------------------------------------------------------------
-- -- Watch for key down/up events that represent modifiers in Super Duper Mode
-- --------------------------------------------------------------------------------
-- superDuperModeModifierKeyListener = eventtap.new({ eventTypes.keyDown, eventTypes.keyUp }, function(event)
--   if not superDuperMode.active then
--     return false
--   end

--   local charactersToModifers = {}
--   charactersToModifers['a'] = 'alt'
--   charactersToModifers['f'] = 'cmd'
--   charactersToModifers[' '] = 'shift'

--   local modifier = charactersToModifers[event:getCharacters()]
--   if modifier then
--     if (event:getType() == eventTypes.keyDown) then
--       superDuperMode.modifiers[modifier] = true
--     else
--       superDuperMode.modifiers[modifier] = nil
--     end
--     return true
--   end
-- end):start()

-- --------------------------------------------------------------------------------
-- -- Watch for h/j/k/l key down events in Super Duper Mode, and trigger the
-- -- corresponding arrow key events
-- --------------------------------------------------------------------------------
-- superDuperModeNavListener = eventtap.new({ eventTypes.keyDown }, function(event)
--   if not superDuperMode.active then
--     return false
--   end

--   local charactersToKeystrokes = {
--     j = 'left',
--     k = 'down',
--     i = 'up',
--     l = 'right',
--   }

--   local keystroke = charactersToKeystrokes[event:getCharacters(true):lower()]
--   if keystroke then
--     local modifiers = {}
--     n = 0
--     -- Apply the custom Super Duper Mode modifier keys that are active (if any)
--     for k, v in pairs(superDuperMode.modifiers) do
--       n = n + 1
--       modifiers[n] = k
--     end
--     -- Apply the standard modifier keys that are active (if any)
--     for k, v in pairs(event:getFlags()) do
--       n = n + 1
--       modifiers[n] = k
--     end

--     keyUpDown(modifiers, keystroke)
--     return true
--   end
-- end):start()

-- --------------------------------------------------------------------------------
-- -- Watch for i/o key down events in Super Duper Mode, and trigger the
-- -- corresponding key events to navigate to the previous/next tab respectively
-- --------------------------------------------------------------------------------
-- superDuperModeTabNavKeyListener = eventtap.new({ eventTypes.keyDown }, function(event)
--   if not superDuperMode.active then
--     return false
--   end

--   local charactersToKeystrokes = {
--     -- u = { {'cmd'}, '1' },          -- go to first tab
--     u = { {'cmd', 'shift'}, '[' }, -- go to previous tab
--     o = { {'cmd', 'shift'}, ']' }, -- go to next tab
--     -- p = { {'cmd'}, '9' },          -- go to last tab
--   }
--   local keystroke = charactersToKeystrokes[event:getCharacters()]

--   if keystroke then
--     keyUpDown(table.unpack(keystroke))
--     return true
--   end
-- end):start()
