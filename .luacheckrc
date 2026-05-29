-- luacheck configuration.
--
-- luacheck is the logic-only linter here: it owns unused variables, undefined
-- globals, shadowing, and unreachable code. All formatting and whitespace
-- concerns belong to StyLua, so every whitespace/line-length diagnostic is
-- switched off below (the luacheck analog of eslint-config-prettier).

-- `hs` is the Hammerspoon global, available everywhere at runtime. Mark it
-- read-only so `hs.*` references are never flagged as undefined, but assigning
-- to `hs` itself is still caught.
read_globals = { 'hs' }

-- Deliberate top-level globals (see CLAUDE.md). They MUST be globals, not
-- locals: the pathwatchers would otherwise be garbage-collected and stop
-- firing, and keyUpDown / enableHotkeyForWindowsMatchingFilter are intended as
-- module-level helpers callable from other files. Declared here so luacheck
-- treats them as known writable globals instead of flagging the assignment.
globals = {
  'configWatcher',
  'keyboardWatcher',
  'keyUpDown',
  'enableHotkeyForWindowsMatchingFilter',
}

-- Let StyLua own line length and spacing.
max_line_length = false

-- Never lint vendored/installed code, mirroring `.styluaignore`. The EmmyLua
-- Spoon under hammerspoon/Spoons/ is vendored upstream code we don't own, and
-- lua_modules/ is the LuaRocks install tree (busted, luacheck themselves).
exclude_files = {
  'hammerspoon/Spoons/',
  'lua_modules/',
}

-- Silence luacheck's whitespace/formatting diagnostics so it never contradicts
-- StyLua. These are the W6xx ("formatting") family:
--   611 line contains only whitespace
--   612 line contains trailing whitespace
--   613 trailing whitespace in a string
--   614 trailing whitespace in a comment
--   621 inconsistent indentation (SPACE followed by TAB)
--   631 line too long  (also covered by max_line_length = false)
ignore = {
  '611',
  '612',
  '613',
  '614',
  '621',
  '631',
}

-- windows.lua deliberately attaches custom layout functions onto hs.window
-- itself (e.g. hs.window.left, hs.window.upRight) — a documented pattern in
-- CLAUDE.md so the modal can look them up dynamically off the window object.
-- Mark hs.window as a writable field here so those assignments aren't flagged
-- as "setting read-only field of global hs". The default read-only `hs` still
-- applies everywhere else.
files['hammerspoon/windows.lua'] = {
  globals = { 'hs.window' },
}

-- Test files use busted's globals (describe, it, assert, setup, teardown, ...).
-- Apply busted's standard set on top of the default Lua globals there so they
-- are recognized instead of flagged as undefined.
files['spec/'] = {
  std = '+busted',
}
