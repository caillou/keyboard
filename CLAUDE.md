# CLAUDE.md

Guidance for Claude Code working in this repo. This file is a **router**: it
orients you and points to where detail lives. It is not an archive — rationale
lives next to the code/config it governs, architecture vocabulary in
`CONTEXT.md`, contested decisions in `docs/adr/`.

A personal macOS keyboard customization built on Hammerspoon. All logic is Lua
loaded at startup; there is no build step. See `CONTEXT.md` for the glossary
(Engine, Adapter, Roll, Chord, …) and `README.md` for the human quickstart.

## Orientation

- **Module resolution (non-obvious).** `script/setup` symlinks this repo's
  `hammerspoon/` to `~/.hammerspoon/keyboard`, so at Hammerspoon runtime files
  address each other as `keyboard.<name>` (e.g. `require('keyboard.windows')`).
  Specs run under plain `lua` with no symlink, so they `require('space-fn-engine')`
  with **no** `keyboard.` prefix — `.busted` puts `./hammerspoon/?.lua` on the
  path to make that resolve. Don't "fix" the asymmetry; it's load-bearing.
- **Entry point** is `hammerspoon/init.lua`, loaded because the user's
  `~/.hammerspoon/init.lua` contains `require('keyboard')`.

## Subsystems

1. **Window layout mode** — `windows.lua` (bindings inline). A `Ctrl+s`
   modal that moves/resizes the focused window with single keys. See the header
   comment in `windows.lua` for the design (layout fns attached to `hs.window`,
   why it's hand-rolled, frame-vs-fullFrame).
2. **Space-fn** — `space-fn-engine.lua` (pure, tested state machine) +
   `space-fn.lua` (thin `hs` adapter). Vocabulary and the tap/hold/Roll/Chord
   model: `CONTEXT.md`. Why the adapter stays thin: `docs/adr/0001`.

## Working in the repo

- **Setup / reload:** `make install` (see `README.md`). Operational gotchas are
  commented in `script/setup`. A `pathwatcher` auto-reloads on any `.lua` change;
  **Shift+Ctrl+`** is the manual fallback. The `hs` CLI is installed so you can
  reload/inspect from a terminal: `hs -c "hs.reload()"`.
- **Testing:** `make test` / `make test-watch` (see `README.md`). Only the Engine
  is unit-tested — why, and the rule "push decisions into the engine rather than
  mock `hs`": `docs/adr/0001`.
- **Tooling:** `make fmt` / `make lint`. StyLua (format), luacheck (logic lint),
  LuaLS (LSP), shellcheck — each owns one concern and is configured not to fight
  the others; that rationale lives in `stylua.toml`, `.luacheckrc`, and
  `.vscode/settings.json`. `hs.*` autocomplete comes from the vendored
  `EmmyLua.spoon` (generated `annotations/`, gitignored). All checks are enforced
  at commit by a lefthook pre-commit hook (`make fmt-check`, `make lint`,
  `make test`); why lefthook and not CI: `docs/adr/0002`.
- **Backlog:** PRDs and their issue/review files live under `docs/PRDs/`.

## Dependencies

No blanket ban. Evaluate each dependency (Spoon, rock, extension) on its merits —
weigh not-invented-here against needless complexity; don't reach for or reject
one reflexively.

## References

- Hammerspoon API index: https://www.hammerspoon.org/docs/ (per-module pages at
  `https://www.hammerspoon.org/docs/<module>.html`). The modules this repo uses
  are visible in the `require`s across `hammerspoon/*.lua`.
