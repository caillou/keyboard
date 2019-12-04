local eventtap = hs.eventtap
local eventTypes = hs.eventtap.event.types

local state = {}
state.isActive = false
state.outputNextSpace = false

superDuperModeActivationListener = eventtap.new({ eventTypes.keyDown }, function(event)
  local character = event:getCharacters()
  hs.logger.new('hyper'):e('down:', character)

  if character == ' ' then
    if not state.outputNextSpace then
      hs.logger.new('hyper'):e('down-enter', character)
      -- prevent the printing of the space
      state.isActive = true
      state.wasUsed = false
      return true
    else
      state.outputNextSpace = false
    end
  end

end):start()

superDuperModeDeactivationListener = eventtap.new({ eventTypes.keyUp }, function(event)

  local character = event:getCharacters()
  hs.logger.new('hyper'):e('up:', character)
  if not state.isActive then
    return
  end
  if character == ' ' then

    state.isActive = false

    if not state.wasUsed then
      state.outputNextSpace = true
      hs.timer.doAfter(0, function ()
        hs.eventtap.keyStroke({}, 'space', 0)
      end)
    end

    return
  end

  state.wasUsed = true

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
