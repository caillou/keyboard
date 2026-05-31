local M = {}

-- Type annotations only (LuaLS / EmmyLua). These document the Engine's
-- stringly-typed token protocol so a mistyped token or an undefined action
-- field is flagged in the editor. They add no runtime behavior: the Engine
-- still accepts any string and falls through to its defaults (runtime token
-- validation is deliberately out of scope).

--- Abstract input the Adapter feeds the Engine, naming a physical occurrence
--- with no `hs` detail.
---@enum EventToken
local EventToken = {
  spaceDown = "space-down",
  spaceDownAutorepeat = "space-down-autorepeat",
  spaceUp = "space-up",
  keyDown = "key-down",
  keyUp = "key-up",
  timerFire = "timer-fire",
}

--- Abstract output the Engine returns for the Adapter to perform (the `type`
--- field of every action object).
---@enum ActionToken
local ActionToken = {
  emitSpace = "emit-space",
  emitKey = "emit-key",
  emitRemap = "emit-remap",
  suppress = "suppress",
  passthrough = "passthrough",
  startTimer = "start-timer",
  cancelTimer = "cancel-timer",
}

--- A remap target: either a bare key name (e.g. `"left"`) or a key plus
--- modifiers to synthesize (e.g. `{ mods = { "cmd", "shift" }, key = "[" }`).
---@class Remap
---@field key string
---@field mods string[]

---@alias RemapTarget string | Remap

--- A keymap entry: maps a physical key name to its remap target. The keymap
--- passed to `M.new` is `table<string, RemapTarget>`.
---@alias Keymap table<string, RemapTarget>

--- Payload accompanying a `key-down` / `key-up` event token.
---@class KeyPayload
---@field key string                physical key name
---@field mods? string[]            physical modifiers held at the time

--- An action object the Engine returns. Plain actions carry only `type`;
--- `emit-key` and `emit-remap` add payload fields below.
---@class Action
---@field type ActionToken
---@field key? string              (emit-key) literal key to emit
---@field mods? string[]           (emit-key) modifiers to emit with the key
---@field remap? RemapTarget       (emit-remap) the remap target to perform
---@field physMods? string[]       (emit-remap) physical modifiers to preserve

--- Options for `M.new`.
---@class EngineOpts
---@field keymap? Keymap

---@param mods? string[]
---@return string[]
local function copyMods(mods)
  local out = {}
  if mods then
    for i, m in ipairs(mods) do
      out[i] = m
    end
  end
  return out
end

local function isBuffered(buffer, key)
  for _, entry in ipairs(buffer) do
    if entry.key == key then
      return true
    end
  end
  return false
end

---@param opts? EngineOpts
---@return table engine
function M.new(opts)
  opts = opts or {}
  local self = setmetatable({}, { __index = M })
  self.keymap = opts.keymap or {}
  self.state = "idle"
  self.buffer = {}
  return self
end

function M:_reset()
  self.state = "idle"
  self.buffer = {}
end

---@param event EventToken
---@param payload? KeyPayload
---@return Action[]
function M:advance(event, payload)
  payload = payload or {}
  local state = self.state

  if state == "idle" then
    if event == EventToken.spaceDown or event == EventToken.spaceDownAutorepeat then
      self.state = "pending"
      self.buffer = {}
      return { { type = ActionToken.startTimer }, { type = ActionToken.suppress } }
    end
    return { { type = ActionToken.passthrough } }
  end

  if state == "pending" then
    if event == EventToken.spaceDown or event == EventToken.spaceDownAutorepeat then
      return { { type = ActionToken.suppress } }
    end

    if event == EventToken.keyDown then
      local key = payload.key
      local mods = copyMods(payload.mods)
      local remap = self.keymap[key]
      if remap ~= nil then
        if not isBuffered(self.buffer, key) then
          table.insert(self.buffer, { key = key, mods = mods, remap = remap })
        end
        return { { type = ActionToken.suppress } }
      else
        local actions = {
          { type = ActionToken.cancelTimer },
          { type = ActionToken.emitSpace },
          { type = ActionToken.emitKey, key = key, mods = mods },
        }
        self:_reset()
        return actions
      end
    end

    if event == EventToken.keyUp then
      local key = payload.key
      if isBuffered(self.buffer, key) then
        local actions = { { type = ActionToken.cancelTimer } }
        for _, entry in ipairs(self.buffer) do
          table.insert(actions, {
            type = ActionToken.emitRemap,
            remap = entry.remap,
            physMods = copyMods(entry.mods),
          })
        end
        self.state = "committed-fn"
        self.buffer = {}
        return actions
      else
        return { { type = ActionToken.passthrough } }
      end
    end

    if event == EventToken.spaceUp then
      local actions = {
        { type = ActionToken.cancelTimer },
        { type = ActionToken.emitSpace },
      }
      for _, entry in ipairs(self.buffer) do
        table.insert(actions, {
          type = ActionToken.emitKey,
          key = entry.key,
          mods = copyMods(entry.mods),
        })
      end
      self:_reset()
      return actions
    end

    if event == EventToken.timerFire then
      local actions = {}
      for _, entry in ipairs(self.buffer) do
        table.insert(actions, {
          type = ActionToken.emitRemap,
          remap = entry.remap,
          physMods = copyMods(entry.mods),
        })
      end
      self.state = "committed-fn"
      self.buffer = {}
      return actions
    end

    return {}
  end

  if state == "committed-fn" then
    if event == EventToken.spaceDown or event == EventToken.spaceDownAutorepeat then
      return { { type = ActionToken.suppress } }
    end

    if event == EventToken.keyDown then
      local key = payload.key
      local mods = copyMods(payload.mods)
      local remap = self.keymap[key]
      if remap ~= nil then
        return {
          {
            type = ActionToken.emitRemap,
            remap = remap,
            physMods = mods,
          },
        }
      else
        return { { type = ActionToken.suppress } }
      end
    end

    if event == EventToken.keyUp then
      return { { type = ActionToken.passthrough } }
    end

    if event == EventToken.spaceUp then
      self:_reset()
      return {}
    end

    if event == EventToken.timerFire then
      return {}
    end

    return {}
  end

  return {}
end

return M
