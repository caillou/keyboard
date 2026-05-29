local M = {}

local function copyMods(mods)
  local out = {}
  if mods then
    for i, m in ipairs(mods) do out[i] = m end
  end
  return out
end

local function isBuffered(buffer, key)
  for _, entry in ipairs(buffer) do
    if entry.key == key then return true end
  end
  return false
end

function M.new(opts)
  opts = opts or {}
  local self = setmetatable({}, { __index = M })
  self.keymap = opts.keymap or {}
  self.state = 'idle'
  self.buffer = {}
  return self
end

function M:_reset()
  self.state = 'idle'
  self.buffer = {}
end

function M:advance(event, payload)
  payload = payload or {}
  local state = self.state

  if state == 'idle' then
    if event == 'space-down' or event == 'space-down-autorepeat' then
      self.state = 'pending'
      self.buffer = {}
      return { { type = 'start-timer' }, { type = 'suppress' } }
    end
    return { { type = 'passthrough' } }
  end

  if state == 'pending' then
    if event == 'space-down' or event == 'space-down-autorepeat' then
      return { { type = 'suppress' } }
    end

    if event == 'key-down' then
      local key = payload.key
      local mods = copyMods(payload.mods)
      local remap = self.keymap[key]
      if remap ~= nil then
        if not isBuffered(self.buffer, key) then
          table.insert(self.buffer, { key = key, mods = mods, remap = remap })
        end
        return { { type = 'suppress' } }
      else
        local actions = {
          { type = 'cancel-timer' },
          { type = 'emit-space' },
          { type = 'emit-key', key = key, mods = mods },
        }
        self:_reset()
        return actions
      end
    end

    if event == 'key-up' then
      local key = payload.key
      if isBuffered(self.buffer, key) then
        local actions = { { type = 'cancel-timer' } }
        for _, entry in ipairs(self.buffer) do
          table.insert(actions, {
            type = 'emit-remap',
            remap = entry.remap,
            physMods = copyMods(entry.mods),
          })
        end
        self.state = 'committed-fn'
        self.buffer = {}
        return actions
      else
        return { { type = 'passthrough' } }
      end
    end

    if event == 'space-up' then
      local actions = {
        { type = 'cancel-timer' },
        { type = 'emit-space' },
      }
      for _, entry in ipairs(self.buffer) do
        table.insert(actions, {
          type = 'emit-key',
          key = entry.key,
          mods = copyMods(entry.mods),
        })
      end
      self:_reset()
      return actions
    end

    if event == 'timer-fire' then
      local actions = {}
      for _, entry in ipairs(self.buffer) do
        table.insert(actions, {
          type = 'emit-remap',
          remap = entry.remap,
          physMods = copyMods(entry.mods),
        })
      end
      self.state = 'committed-fn'
      self.buffer = {}
      return actions
    end

    return {}
  end

  if state == 'committed-fn' then
    if event == 'space-down' or event == 'space-down-autorepeat' then
      return { { type = 'suppress' } }
    end

    if event == 'key-down' then
      local key = payload.key
      local mods = copyMods(payload.mods)
      local remap = self.keymap[key]
      if remap ~= nil then
        return { {
          type = 'emit-remap',
          remap = remap,
          physMods = mods,
        } }
      else
        return { { type = 'suppress' } }
      end
    end

    if event == 'key-up' then
      return { { type = 'passthrough' } }
    end

    if event == 'space-up' then
      self:_reset()
      return {}
    end

    if event == 'timer-fire' then
      return {}
    end

    return {}
  end

  return {}
end

return M
