# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal macOS keyboard customization built on Hammerspoon. All logic is Lua loaded by Hammerspoon at startup. There is no build step. Tests for the space-fn state machine run under busted (see "Testing" below).

## Setup and reload

- `script/setup` — installs dependencies via `brew bundle`, symlinks `hammerspoon/` into `~/.hammerspoon/keyboard`, appends `require('keyboard')` to `~/.hammerspoon/init.lua`, hides the Hammerspoon dock icon, and (re)launches Hammerspoon. Idempotent; safe to re-run after pulling.
- A `hs.pathwatcher` in `init.lua` auto-reloads on any `.lua` change under `~/.hammerspoon/`. **Shift+Ctrl+`** is still bound as a manual fallback.
- `hs.ipc` is loaded and the `hs` CLI is symlinked into `~/.local/bin` at startup, so config can be reloaded or inspected from a terminal: `hs -c "hs.reload()"`, `hs -c "hs.window.focusedWindow():title()"`, etc. `script/setup` pre-creates `~/.local/bin` and `~/.local/share/man/man1` (cliInstall won't create them itself) and verifies the CLI works at the end of setup. If `~/.local/bin` isn't on `PATH`, the setup script prints `fish_add_path ~/.local/bin` as the one-liner fix (persistent fish universal variable). Also note: cliInstall refuses to repair a half-installed state — if `hs -c "hs.ipc.cliStatus(os.getenv('HOME') .. '/.local')"` returns `false` even though `hs -c "1+1"` works, run `hs.ipc.cliUninstall(...)` then reload.
- Debug from the Hammerspoon Console (menu bar → Hammerspoon → Console). `hs.logger.new(...)` output appears there.

## Architecture

`script/setup` symlinks this repo's `hammerspoon/` directory to `~/.hammerspoon/keyboard`, so within Hammerspoon Lua, this directory is the `keyboard` module. Files reference each other as `keyboard.<name>` (e.g. `require('keyboard.windows')`).

Entry point is `hammerspoon/init.lua`. It is loaded indirectly: the user's `~/.hammerspoon/init.lua` contains `require('keyboard')`, which resolves to this directory's `init.lua` via the symlink.

Two main subsystems:

1. **Window layout mode** (`windows.lua` + `windows-bindings*.lua`) — A modal hotkey activated by `Ctrl+s`. Inside the mode, single keys (`h/j/k/l`, `i/o/m/.`, `return`, `space`, `n`) move/resize the focused window. Layout functions are attached to `hs.window` itself (e.g. `hs.window.left`, `hs.window.upRight`); the modal binds keys to look them up dynamically. `windows-bindings.lua` is user-editable and gitignored; `windows-bindings-defaults.lua` is the fallback loaded via `pcall`. Status overlay rendered by `status-message.lua`.

2. **Space-as-modifier ("space-fn")** (`space-fn-engine.lua` + `space-fn.lua`). Tap space, emit space. Hold space plus another key, treat space as a modifier (e.g. space+j is left-arrow, space+h is delete). Split into two files. `space-fn-engine.lua` is a pure Lua state machine. Its inputs are abstract event tokens (`space-down`, `key-down`, `key-up`, `space-up`, `timer-fire`) and its outputs are abstract action tokens (`emit`, `suppress`, `start-timer`, `cancel-timer`). It has no `hs.*` imports and is the only piece covered by tests. `space-fn.lua` is the thin adapter: it owns the `hs.eventtap`, translates real Hammerspoon events into engine inputs, dispatches engine actions back out, and owns the long-hold `hs.timer`. The tap-vs-hold decision is made on the first key-release (release order), not on press order, which is what makes rolling fingers off space onto the next letter type literally instead of remapping.

`init.lua` also exposes two helpers used (or intended to be used) by other files:
- `keyUpDown(modifiers, key)` — thin wrapper over `hs.eventtap.keyStroke`.
- `enableHotkeyForWindowsMatchingFilter(windowFilter, hotkey)` — enable/disable a hotkey based on which window is focused. Not currently called from anywhere checked in, but kept available for per-app bindings.

## Testing

The space-fn engine is the first piece of code in this repo non-trivial enough to deserve tests. The toolchain:

- **busted**: the test framework, the de facto BDD-style runner for Lua.
- **LuaRocks**: the Lua package manager. Installed via Homebrew (`brew "luarocks"` in `Brewfile`). Treat it like npm for Lua.
- **`lua_modules/`**: the project-local install tree (similar to `node_modules`). `script/setup` runs `luarocks --tree=lua_modules install busted`, so the dependency lives inside the repo and there is no global package pollution. Gitignored.
- **`make install`**: the documented setup entry point. It delegates to `script/setup`.
- **`make test`**: runs `./lua_modules/bin/busted`. **`make test-watch`** runs it with `--watch` for sub-second iteration.
- **`spec/`**: at the repo root, holds the specs following busted's `*_spec.lua` convention. Sits outside `hammerspoon/` so test-file edits do not trigger the Hammerspoon pathwatcher reload.
- **`.busted`**: at the repo root, adds `./hammerspoon/?.lua` to `package.path` so specs `require('space-fn-engine')` (no `keyboard.` prefix) and it resolves to `hammerspoon/space-fn-engine.lua`. The `keyboard.` prefix only works at Hammerspoon runtime because `~/.hammerspoon/keyboard` is a symlink to `hammerspoon/`; busted runs under plain `lua` with no such symlink, hence the asymmetry.

Only `space-fn-engine.lua` is unit-tested. The adapter (`space-fn.lua`) is glue around `hs.eventtap`, `hs.timer`, and `hs.eventtap.keyStroke`; testing it would mean mocking the Hammerspoon runtime. The adapter is verified by using the keyboard.

## Editor and tooling

A small, conventional Lua toolchain mirrors what a JS/TS developer expects (formatter, linter, language server), configured so the tools never fight each other. Three tools, each owning exactly one concern:

- **StyLua** — the formatter (the prettier analog). Owns *all* formatting. Config in `stylua.toml` at the repo root keeps only 2-space indentation (`indent_type = "Spaces"`, `indent_width = 2`) and otherwise follows StyLua defaults (double quotes, 120 column) — the modern Lua/Neovim-ecosystem convention. The vendored EmmyLua Spoon is excluded from formatting via a root `.styluaignore` (`hammerspoon/Spoons/`, plus `lua_modules/` defensively) so it stays byte-for-byte upstream-exact. Run via `make fmt` (writes) and `make fmt-check` (verifies, non-zero exit on drift). Installed via Homebrew (`brew "stylua"`), so the CLI and the VS Code extension share one binary. Runs on save in VS Code.
- **lua-language-server / LuaLS** — the language server: IntelliSense, hover docs, go-to-definition, and type/reference diagnostics. Ships inside the VS Code "Lua" extension (`sumneko.lua`), so nothing extra is installed for it. **Its own formatter is disabled** (`Lua.format.enable = false`) so it does not fight StyLua.
- **luacheck** — the linter (the eslint analog), scoped to logic only (unused vars, undefined globals, shadowing, unreachable code). All formatting and whitespace checks are switched off in `.luacheckrc` (notably `max_line_length = false` plus the W6xx family) so it never contradicts StyLua — the luacheck analog of `eslint-config-prettier`. `.luacheckrc` also declares `hs` as a read global and applies busted's standard set to `spec/`. Run via `make lint`. Installed via LuaRocks into the project-local `lua_modules/` tree, alongside busted. Note: luacheck must build against `lua@5.4` (keg-only, declared in the `Brewfile`) — its source reassigns generic-for loop variables, which Lua 5.5 rejects; `script/setup` handles this with `--lua-version=5.4`.

The separation is the whole point: StyLua formats, luacheck lints logic with formatting checks off, LuaLS's formatter is off. The only tool that formats is StyLua, so there is no eslint-vs-prettier conflict.

**`hs.*` autocomplete (EmmyLua stubs).** Editor awareness of the Hammerspoon API comes from a vendored generator at `hammerspoon/Spoons/EmmyLua.spoon` (MIT, committed unmodified; provenance in its `UPSTREAM.md`). It is a build-time code generator: when Hammerspoon loads it (a guarded `pcall(hs.loadSpoon, 'EmmyLua')` in `init.lua`), it introspects the live, installed `hs` API and writes EmmyLua annotation stubs (the Lua equivalent of TypeScript `.d.ts` files) into `annotations/`. LuaLS reads those stubs (via `Lua.workspace.library` in `.vscode/settings.json`) and provides full `hs.*` autocomplete and signatures. Because the stubs are generated from the installed Hammerspoon version, they cannot drift out of sync with it. The generator guards itself on file mtimes, so it regenerates only when Hammerspoon's docs change (i.e. after a Hammerspoon upgrade) and short-circuits cheaply on ordinary reloads. The `annotations/` directory is gitignored (machine-specific generated output). `script/setup` symlinks `~/.hammerspoon/Spoons/EmmyLua.spoon` to the vendored copy so the generator's writes land inside the repo. To refresh the *generator itself* (rare, deliberate), run `make update-emmylua` (delegates to `script/update-emmylua`, which re-vendors the latest upstream Spoon).

The VS Code config travels with the repo via committed `.vscode/settings.json` and `.vscode/extensions.json`, so opening the repo prompts to install the recommended extensions (`sumneko.lua`, `JohnnyMorganz.stylua`) and applies the no-conflict settings automatically. Open the repo at its real location, not the `~/.hammerspoon/keyboard` symlink — LuaLS resolves poorly through symlinked roots.

## Gitignored local overrides

- `hammerspoon/windows-bindings.lua` — user's personal window-layout key map. Copy `windows-bindings-defaults.lua` to create one.
- `hammerspoon/hyper-apps.lua` — referenced in `.gitignore` but not currently imported anywhere in tracked code.
- `karabiner/automatic_backups` — Karabiner-Elements is commented out in the `Brewfile` and not part of the current flow.

## Conventions worth knowing

- macOS keycode 49 is space; this magic number appears in `space-fn.lua`.
- Window layout functions mutate via `win:setFrame(f)` after computing against `screen:frame()` (excludes menu bar/dock) or `screen:fullFrame()` (full display). The choice differs per function and is deliberate — half-screen layouts use `frame()`, quarter-screen layouts use `fullFrame()`.
- Hammerspoon animation is disabled globally (`hs.window.animationDuration = 0` in `windows.lua`) — window moves should be instant.

## References

- Hammerspoon API index: https://www.hammerspoon.org/docs/
- Modules this repo uses (each has a page at `https://www.hammerspoon.org/docs/<module>.html`):
  - `hs.hotkey`, `hs.hotkey.modal` — global hotkeys and modal layers (the `Ctrl+s` window mode)
  - `hs.eventtap`, `hs.eventtap.event.types` — low-level key capture (space-fn in `space-fn.lua`)
  - `hs.window`, `hs.window.filter` — window manipulation and per-app focus events
  - `hs.screen` — multi-monitor frames
  - `hs.timer` — `absoluteTime`, `doAfter`, debouncing
  - `hs.drawing`, `hs.geometry`, `hs.styledtext` — the status-message overlay
  - `hs.pathwatcher` — config auto-reload
  - `hs.ipc` — `hs` CLI tool
  - `hs.logger`, `hs.notify`, `hs.fnutils`, `hs.keycodes`

## Dependencies: a case-by-case principle

There is no blanket ban on dependencies (Spoons, rocks, extensions). Each is evaluated on its merits — weighing not-invented-here against needless complexity, and favoring good developer experience and current best practices. A future agent reading generic Hammerspoon advice (blog posts, the "hammerspoon" plugin skill) should apply that judgement rather than reach for or reject a tool reflexively. The dev toolchain above (StyLua, luacheck, LuaLS, the vendored EmmyLua.spoon) is exactly this principle in action: each earns its place by improving the editing experience, and the vendored EmmyLua.spoon needs no special carve-out — it is a dev-only tooling Spoon for editor autocomplete, not part of the runtime keyboard logic.

One recorded rationale worth keeping (not dogma, just so nobody regresses it): **`windows.lua` is hand-rolled rather than a stock window-manager Spoon** (ShiftIt, `WindowHalfsAndThirds`, `MiroWindowsManager`, etc.). It supports non-standard layouts (`left40`, `right60`, `centerWithFullHeight`) that those Spoons don't, so swapping one in would be a regression. If you ever reconsider, that capability is the bar to clear.
