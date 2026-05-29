local Engine = require('space-fn-engine')

local KEYMAP = {
  i = 'up',
  j = 'left',
  k = 'down',
  l = 'right',
  h = 'delete',
  u = { mods = { 'cmd', 'shift' }, key = '[' },
  o = { mods = { 'cmd', 'shift' }, key = ']' },
}

local function newEngine()
  return Engine.new({ keymap = KEYMAP })
end

describe('space-fn engine', function()

  describe('tap', function()
    it('emits a literal space when tapped with no other key', function()
      local e = newEngine()
      local a1 = e:advance('space-down')
      local a2 = e:advance('space-up')
      assert.same({ { type = 'start-timer' }, { type = 'suppress' } }, a1)
      assert.same({ { type = 'cancel-timer' }, { type = 'emit-space' } }, a2)
    end)

    it('emits a literal space when space-up arrives before any other key event', function()
      local e = newEngine()
      e:advance('space-down')
      local actions = e:advance('space-up')
      assert.same({ { type = 'cancel-timer' }, { type = 'emit-space' } }, actions)
    end)
  end)

  describe('roll — space-up wins', function()
    it('"and i" emits literal space then literal i', function()
      local e = newEngine()
      e:advance('space-down')
      local down = e:advance('key-down', { key = 'i', mods = {} })
      assert.same({ { type = 'suppress' } }, down)
      local up = e:advance('space-up')
      assert.same({
        { type = 'cancel-timer' },
        { type = 'emit-space' },
        { type = 'emit-key', key = 'i', mods = {} },
      }, up)
    end)

    it('multi-key buffer — space-up first emits space + all buffered keys literally in order', function()
      local e = newEngine()
      e:advance('space-down')
      e:advance('key-down', { key = 'j', mods = {} })
      e:advance('key-down', { key = 'k', mods = {} })
      local up = e:advance('space-up')
      assert.same({
        { type = 'cancel-timer' },
        { type = 'emit-space' },
        { type = 'emit-key', key = 'j', mods = {} },
        { type = 'emit-key', key = 'k', mods = {} },
      }, up)
    end)
  end)

  describe('chord — other-key-up wins', function()
    it('space + j released-then-space → emits remapped left-arrow', function()
      local e = newEngine()
      e:advance('space-down')
      e:advance('key-down', { key = 'j', mods = {} })
      local up = e:advance('key-up', { key = 'j' })
      assert.same({
        { type = 'cancel-timer' },
        { type = 'emit-remap', remap = 'left', physMods = {} },
      }, up)
    end)

    it('space + u released-then-space → emits cmd+shift+[ (prev tab)', function()
      local e = newEngine()
      e:advance('space-down')
      e:advance('key-down', { key = 'u', mods = {} })
      local up = e:advance('key-up', { key = 'u' })
      assert.same({
        { type = 'cancel-timer' },
        { type = 'emit-remap', remap = { mods = { 'cmd', 'shift' }, key = '[' }, physMods = {} },
      }, up)
    end)

    it('multi-key buffer — first non-space release commits whole press to fn-mode', function()
      local e = newEngine()
      e:advance('space-down')
      e:advance('key-down', { key = 'j', mods = {} })
      e:advance('key-down', { key = 'k', mods = {} })
      local up = e:advance('key-up', { key = 'j' })
      assert.same({
        { type = 'cancel-timer' },
        { type = 'emit-remap', remap = 'left', physMods = {} },
        { type = 'emit-remap', remap = 'down', physMods = {} },
      }, up)
    end)

    it('after commit, subsequent keys in same press remap immediately without buffering', function()
      local e = newEngine()
      e:advance('space-down')
      e:advance('key-down', { key = 'j', mods = {} })
      e:advance('key-up', { key = 'j' })
      local next = e:advance('key-down', { key = 'l', mods = {} })
      assert.same({
        { type = 'emit-remap', remap = 'right', physMods = {} },
      }, next)
    end)
  end)

  describe('long-hold commit', function()
    it('holding space alone for 750ms commits silently — no space emitted on release', function()
      local e = newEngine()
      e:advance('space-down')
      local fire = e:advance('timer-fire')
      assert.same({}, fire)
      local up = e:advance('space-up')
      assert.same({}, up)
    end)

    it('holding space + buffered key for 750ms commits and emits remapped buffered key', function()
      local e = newEngine()
      e:advance('space-down')
      e:advance('key-down', { key = 'j', mods = {} })
      local fire = e:advance('timer-fire')
      assert.same({
        { type = 'emit-remap', remap = 'left', physMods = {} },
      }, fire)
    end)
  end)

  describe('pending unmapped abort', function()
    it('space then unmapped key aborts: emits literal space + literal key, returns to idle', function()
      local e = newEngine()
      e:advance('space-down')
      local abort = e:advance('key-down', { key = 'q', mods = {} })
      assert.same({
        { type = 'cancel-timer' },
        { type = 'emit-space' },
        { type = 'emit-key', key = 'q', mods = {} },
      }, abort)
      -- back to idle: another unrelated key passes through
      local pass = e:advance('key-down', { key = 'z', mods = {} })
      assert.same({ { type = 'passthrough' } }, pass)
    end)
  end)

  describe('post-commit unmapped swallow', function()
    it('unmapped key after commit emits nothing', function()
      local e = newEngine()
      e:advance('space-down')
      e:advance('key-down', { key = 'j', mods = {} })
      e:advance('key-up', { key = 'j' })
      local swallow = e:advance('key-down', { key = 'q', mods = {} })
      assert.same({ { type = 'suppress' } }, swallow)
    end)
  end)

  describe('autorepeat', function()
    it('space-down autorepeat events while pending are ignored', function()
      local e = newEngine()
      e:advance('space-down')
      local r1 = e:advance('space-down-autorepeat')
      local r2 = e:advance('space-down-autorepeat')
      assert.same({ { type = 'suppress' } }, r1)
      assert.same({ { type = 'suppress' } }, r2)
      -- still pending: rolling off emits literal space
      local up = e:advance('space-up')
      assert.same({ { type = 'cancel-timer' }, { type = 'emit-space' } }, up)
    end)

    it('autorepeat key-down during pending is absorbed, single key-up emits one remap', function()
      local e = newEngine()
      e:advance('space-down')
      local d1 = e:advance('key-down', { key = 'j', mods = {} })
      local d2 = e:advance('key-down', { key = 'j', mods = {} })
      local d3 = e:advance('key-down', { key = 'j', mods = {} })
      assert.same({ { type = 'suppress' } }, d1)
      assert.same({ { type = 'suppress' } }, d2)
      assert.same({ { type = 'suppress' } }, d3)
      local up = e:advance('key-up', { key = 'j' })
      assert.same({
        { type = 'cancel-timer' },
        { type = 'emit-remap', remap = 'left', physMods = {} },
      }, up)
    end)
  end)

  describe('modifier propagation', function()
    it('arrow remaps emit with currently-held physical modifiers preserved', function()
      local e = newEngine()
      e:advance('space-down')
      e:advance('key-down', { key = 'j', mods = { 'cmd', 'shift' } })
      local up = e:advance('key-up', { key = 'j' })
      assert.same({
        { type = 'cancel-timer' },
        { type = 'emit-remap', remap = 'left', physMods = { 'cmd', 'shift' } },
      }, up)
    end)
  end)

end)
