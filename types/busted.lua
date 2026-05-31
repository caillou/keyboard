---@meta

-- Type definitions for busted's `assert` (the luassert library), consumed by
-- LuaLS only — this file is never executed or required.
--
-- Why it exists: LuaLS types the global `assert` as the standard-library
-- function `assert(v, message)`, which has no fields. Specs call `assert.same`,
-- so without this file every `assert.<method>` is flagged `undefined-field`
-- (raised to Error in .vscode/settings.json). Listing `assert` in
-- `Lua.diagnostics.globals` can't help — that registers the name, not the type.
-- This redefines `assert` as the luassert object: still callable (the
-- @overload), now with the assertion methods as fields.
--
-- Wired in via `Lua.workspace.library` in .vscode/settings.json, mirroring how
-- hs.* types come from the vendored EmmyLua.spoon/annotations. Engine code never
-- calls assert(), so widening its type workspace-wide costs nothing there.
--
-- Add methods here as specs start using them (assert.equal, assert.is_true, …);
-- full luassert API: https://lunarmodules.github.io/busted/#asserts

---@class luassert
---@overload fun(value: any, message?: any, ...): any
assert = {}

--- Deep (recursive) equality of two values.
---@param expected any
---@param actual any
---@param message? string
function assert.same(expected, actual, message) end
