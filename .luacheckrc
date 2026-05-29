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

-- Let StyLua own line length and spacing.
max_line_length = false

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

-- Test files use busted's globals (describe, it, assert, setup, teardown, ...).
-- Apply busted's standard set on top of the default Lua globals there so they
-- are recognized instead of flagged as undefined.
files['spec/'] = {
  std = '+busted',
}
