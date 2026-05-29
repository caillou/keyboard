local Engine = require('keyboard.space-fn-engine')

local KEYMAP = {
  i = 'up',
  j = 'left',
  k = 'down',
  l = 'right',
  h = 'delete',
  u = { mods = {'cmd', 'shift'}, key = '[' },
  o = { mods = {'cmd', 'shift'}, key = ']' },
  v = { mods = {'ctrl', 'alt'}, key = 'v' },
}

local COMMIT_HOLD_MS = 750
local SPACE_KEYCODE = 49
local SYNTHETIC_MARKER = 0xC1AC1ED

local log = hs.logger.new('space-fn', 'info')

local M = {}
M.log = log

local state = {
  enabled = true,
  timer = nil,
  tap = nil,
}

local engine = Engine.new({ keymap = KEYMAP })

local MOD_ORDER = { 'alt', 'cmd', 'ctrl', 'fn', 'shift' }

local function flagsToList(flags)
  local out = {}
  for _, name in ipairs(MOD_ORDER) do
    if flags[name] then out[#out + 1] = name end
  end
  return out
end

local function emitKey(mods, key)
  local down = hs.eventtap.event.newKeyEvent(mods or {}, key, true)
  down:setProperty(hs.eventtap.event.properties.eventSourceUserData, SYNTHETIC_MARKER)
  down:post()
  local up = hs.eventtap.event.newKeyEvent(mods or {}, key, false)
  up:setProperty(hs.eventtap.event.properties.eventSourceUserData, SYNTHETIC_MARKER)
  up:post()
end

local executeActions

local function onTimerFire()
  state.timer = nil
  local actions = engine:advance('timer-fire')
  log.d('engine input:', 'timer-fire')
  log.d('engine output:', hs.inspect(actions))
  executeActions(actions)
end

executeActions = function(actions)
  local suppress = true
  local sawPassthrough = false
  for _, action in ipairs(actions) do
    local t = action.type
    if t == 'emit-space' then
      emitKey(flagsToList(hs.eventtap.checkKeyboardModifiers()), 'space')
    elseif t == 'emit-key' then
      emitKey(action.mods, action.key)
    elseif t == 'emit-remap' then
      local remap = action.remap
      if type(remap) == 'string' then
        emitKey(action.physMods, remap)
      else
        emitKey(remap.mods, remap.key)
      end
    elseif t == 'start-timer' then
      if state.timer then state.timer:stop() end
      state.timer = hs.timer.doAfter(COMMIT_HOLD_MS / 1000, onTimerFire)
    elseif t == 'cancel-timer' then
      if state.timer then state.timer:stop(); state.timer = nil end
    elseif t == 'passthrough' then
      sawPassthrough = true
    elseif t == 'suppress' then
      -- default; nothing to do
    end
  end
  if sawPassthrough then suppress = false end
  return suppress
end

local function onEvent(event)
  if not state.enabled then return false end
  if event:getProperty(hs.eventtap.event.properties.eventSourceUserData) == SYNTHETIC_MARKER then
    return false
  end

  local keycode = event:getKeyCode()
  local eventType = event:getType()
  local isKeyDown = eventType == hs.eventtap.event.types.keyDown
  local eventName, payload

  if keycode == SPACE_KEYCODE then
    if isKeyDown then
      local repeating = event:getProperty(hs.eventtap.event.properties.keyboardEventAutorepeat) == 1
      eventName = repeating and 'space-down-autorepeat' or 'space-down'
    else
      eventName = 'space-up'
    end
  else
    local keyName = hs.keycodes.map[keycode] or tostring(keycode)
    if isKeyDown then
      eventName = 'key-down'
      payload = { key = keyName, mods = flagsToList(event:getFlags()) }
    else
      eventName = 'key-up'
      payload = { key = keyName }
    end
  end

  log.d('engine input:', eventName, payload and hs.inspect(payload) or '')
  local actions = engine:advance(eventName, payload)
  log.d('engine output:', hs.inspect(actions))
  return executeActions(actions)
end

function M.start()
  if state.tap then return end
  state.tap = hs.eventtap.new(
    { hs.eventtap.event.types.keyDown, hs.eventtap.event.types.keyUp },
    onEvent
  )
  state.tap:start()
end

function M.stop()
  if state.tap then state.tap:stop(); state.tap = nil end
  if state.timer then state.timer:stop(); state.timer = nil end
end

function M.setEnabled(bool)
  state.enabled = bool
end

return M
