local eventtap = hs.eventtap
local eventTypes = hs.eventtap.event.types
local l = hs.logger.new('super')

local state = {}

local resetState = function ()
  state.spaceDown = false
  state.spaceFn = false
  state.outputNextSpace = false
  state.pause = false
end

resetState()

local modifiers = function (event)
  local modifiers = {}

  for k, v in pairs(event:getFlags()) do
    table.insert(modifiers, k)
  end
  return modifiers
end


local onSpaceDown = function ()


  if state.spaceDown then
    state.spaceFn = true
  else
    state.spaceDown = true
  end
  return true
end

local onKeyUp, onKeyDown

local onSpaceUp = function (event)

  if not state.spaceFn then

    onKeyUp:stop()
    onKeyDown:stop()

    state.outputNextSpace = true
    hs.eventtap.keyStroke(
      modifiers(event),
      'space',
      0
    )

    onKeyUp:start()
    onKeyDown:start()

  end
  resetState()

end

local spaceKeycode = 49

onKeyDown = eventtap.new(
  {eventTypes.keyDown},
  function (event)
    local keycode = event:getKeyCode()
    if keycode == spaceKeycode then
        return onSpaceDown()
    end
  end
)

onKeyUp = eventtap.new(
  {eventTypes.keyUp},
  function (event)
    local keycode = event:getKeyCode()
    if keycode == spaceKeycode then
      return onSpaceUp(event)
    end
  end
)

onKeyDown:start()
onKeyUp:start()
