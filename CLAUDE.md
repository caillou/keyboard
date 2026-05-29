# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

A personal macOS keyboard customization built on Hammerspoon. All logic is Lua loaded by Hammerspoon at startup. There is no build, no test runner, and no package manager beyond Homebrew (see `Brewfile`).

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

2. **Space-as-modifier ("space-fn")** (`super.lua`, with earlier attempts in `super-new.lua` and `super-backup.lua`) — Work-in-progress (see recent commit messages). The intent: tap space → emit space; hold space + another key → treat space as a modifier. The implementation uses `hs.eventtap` on keyDown/keyUp for keycode 49 and times the hold. **`super.lua` is not currently `require`d from `init.lua`** — only `windows` is wired in. `super-backup.lua` contains a fuller (commented-out) version with navigation mappings (`i/j/k/l` → arrows), app-switching, bracket shortcuts, and a "touch typing training" mode that rejects arrow keys. Treat these files as scratchpads, not as a stable API.

`init.lua` also exposes two helpers used (or intended to be used) by other files:
- `keyUpDown(modifiers, key)` — thin wrapper over `hs.eventtap.keyStroke`.
- `enableHotkeyForWindowsMatchingFilter(windowFilter, hotkey)` — enable/disable a hotkey based on which window is focused. Not currently called from anywhere checked in, but kept available for per-app bindings.

## Gitignored local overrides

- `hammerspoon/windows-bindings.lua` — user's personal window-layout key map. Copy `windows-bindings-defaults.lua` to create one.
- `hammerspoon/hyper-apps.lua` — referenced in `.gitignore` but not currently imported anywhere in tracked code.
- `karabiner/automatic_backups` — Karabiner-Elements is commented out in the `Brewfile` and not part of the current flow.

## Conventions worth knowing

- macOS keycode 49 is space; this magic number appears throughout `super*.lua`.
- Window layout functions mutate via `win:setFrame(f)` after computing against `screen:frame()` (excludes menu bar/dock) or `screen:fullFrame()` (full display). The choice differs per function and is deliberate — half-screen layouts use `frame()`, quarter-screen layouts use `fullFrame()`.
- Hammerspoon animation is disabled globally (`hs.window.animationDuration = 0` in `windows.lua`) — window moves should be instant.

## References

- Hammerspoon API index: https://www.hammerspoon.org/docs/
- Modules this repo uses (each has a page at `https://www.hammerspoon.org/docs/<module>.html`):
  - `hs.hotkey`, `hs.hotkey.modal` — global hotkeys and modal layers (the `Ctrl+s` window mode)
  - `hs.eventtap`, `hs.eventtap.event.types` — low-level key capture (space-fn experiments in `super*.lua`)
  - `hs.window`, `hs.window.filter` — window manipulation and per-app focus events
  - `hs.screen` — multi-monitor frames
  - `hs.timer` — `absoluteTime`, `doAfter`, debouncing
  - `hs.drawing`, `hs.geometry`, `hs.styledtext` — the status-message overlay
  - `hs.pathwatcher` — config auto-reload
  - `hs.ipc` — `hs` CLI tool
  - `hs.logger`, `hs.notify`, `hs.fnutils`, `hs.keycodes`

## Deliberate non-choices

A future agent reading generic Hammerspoon advice (e.g. blog posts, the "hammerspoon" plugin skill) will see these suggestions. **Don't apply them here** without asking:

- **Spoons / SpoonInstall** — not used. The repo is a handful of files loaded with plain `require`; a plugin system adds ceremony with no benefit at this size.
- **ShiftIt** (or `WindowHalfsAndThirds`, `MiroWindowsManager`, etc.) — not used. The custom `windows.lua` supports non-standard layouts (`left40`, `right60`, `centerWithFullHeight`) that those Spoons don't, so swapping in a Spoon would be a regression.
- **`ReloadConfiguration` Spoon** — not used; the inline `hs.pathwatcher` in `init.lua` does the same job in ~6 lines.
