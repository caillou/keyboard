# Lua Dev Tooling (formatting, linting, editor autocomplete)

## Problem Statement

I maintain this Hammerspoon keyboard config but I am not fluent in Lua. I come from the JS/TS world, where formatting, linting, and editor autocomplete are a given (prettier, eslint, a language server). Working in this repo today I get none of that:

- No auto-formatting, so style drifts and I think about whitespace by hand.
- No editor diagnostics, so typos and undefined references only surface when Hammerspoon misbehaves at runtime.
- No autocomplete for the `hs.*` API, which is the single biggest pain for someone who does not have the Hammerspoon API memorized. I cannot discover what `hs.window` offers without leaving the editor for the web docs.

The repo's CLAUDE.md also leans hard toward "minimal ceremony / no extra tooling," which has discouraged adding any of this. That stance made sense when the repo was a handful of glue files. It now reads as not-invented-here friction that blocks a good developer experience.

This work is sequenced to land **after** the space-fn PRD (`docs/PRDs/2026-05-29-space-fn/prd.md`). That PRD introduces the foundation this one builds on: a `Makefile`, LuaRocks via Homebrew, a project-local `lua_modules/` tree, busted tests under `spec/`, and a partial rewrite of CLAUDE.md. Doing this tooling work first would mean the space-fn PRD immediately rewrites the same files (CLAUDE.md, Brewfile, .gitignore, script/setup, README, Makefile). Going second lets us build on that foundation instead of colliding with it.

## Solution

Add a small, conventional Lua toolchain that mirrors what a JS/TS developer expects, configured so the tools never fight each other, and wire it into the existing setup and Makefile flow so it stays one-command.

Three tools, each in its own lane:

- **StyLua** is the formatter (the prettier analog). Configured to match the repo's existing house style so adopting it produces near-zero churn. Runs on save in the editor and via `make fmt` / `make fmt-check`.
- **lua-language-server (LuaLS)** is the language server (IntelliSense, hover docs, go-to-definition, diagnostics). It ships inside the VS Code "Lua" extension. Its built-in formatter is turned off so it does not fight StyLua.
- **luacheck** is the linter (the eslint analog), scoped to logic only (unused vars, undefined globals, shadowing, unreachable code). All formatting and whitespace checks are delegated to StyLua, so there is no eslint-vs-prettier-style conflict. Runs via `make lint`. luacheck installs through LuaRocks into the same `lua_modules/` tree the space-fn PRD establishes for busted.

Editor awareness of the Hammerspoon API is provided by **vendoring EmmyLua.spoon** (MIT licensed) into the repo. EmmyLua.spoon is a build-time code generator: when Hammerspoon loads it, it introspects the live, installed `hs` API and writes EmmyLua annotation stub files (the Lua equivalent of TypeScript `.d.ts` files). LuaLS reads those stubs and provides full `hs.*` autocomplete and signatures. Because the stubs are generated from the installed Hammerspoon version, they cannot drift out of sync with it. Vendoring the generator (rather than fetching it at setup) guarantees every machine runs identical generator code and keeps `script/setup` offline-safe.

The VS Code configuration travels with the repo via committed `.vscode/settings.json` and `.vscode/extensions.json`, so opening the repo prompts to install the right extensions and applies the no-conflict settings automatically.

CLAUDE.md's "Deliberate non-choices" section is reframed from a list of prohibitions into a single case-by-case principle plus the one entry that carries real technical rationale. The README gains a short pointer to the tooling. The LICENSE gains the current maintainer alongside the original author.

## User Stories

1. As a developer new to Lua, I want my Lua files auto-formatted on save, so that I never think about indentation, quotes, or spacing.
2. As a developer, I want formatting to match the repo's existing style (2-space indent, single quotes, ~100 column), so that adopting the formatter does not rewrite every existing file.
3. As a developer, I want a one-time baseline format pass committed up front, so that future diffs are never polluted by an untouched file getting reformatted the first time I happen to open it.
4. As a developer, I want to see the baseline-format diff before it is committed, so that I can confirm it is the near-no-op I expect.
5. As a developer, I want `make fmt` to format the whole repo from the command line, so that I can format without an editor.
6. As a developer, I want `make fmt-check` to verify formatting without modifying files, so that I can check formatting in a quick pass.
7. As a developer new to Lua, I want editor autocomplete for the `hs.*` API, so that I can discover available functions without leaving the editor for the web docs.
8. As a developer, I want hover documentation and signatures for `hs.*` calls, so that I understand a function's arguments inline.
9. As a developer, I want go-to-definition and diagnostics from the language server, so that typos and undefined references surface as I type rather than at Hammerspoon runtime.
10. As a developer, I want the language server's own formatter disabled, so that it does not fight StyLua over formatting.
11. As a developer, I want `make lint` to run a linter that reports only logic issues (unused variables, undefined globals, shadowing, unreachable code), so that I catch real mistakes.
12. As a developer, I want the linter to defer all formatting and whitespace concerns to StyLua, so that I never get contradictory squiggles from two tools.
13. As a developer, I want the linter to know that `hs` is a valid global, so that every `hs.*` reference is not flagged as undefined.
14. As a developer, I want the linter to recognize busted's test globals (`describe`, `it`, `assert`, and friends) in `spec/`, so that test files do not produce a wall of undefined-global warnings.
15. As a developer, I want the autocomplete stubs generated from my installed Hammerspoon version, so that the API I see in the editor matches the API I actually have.
16. As a developer, I want the stubs to regenerate automatically when I upgrade Hammerspoon, so that I never manually refresh them.
17. As a developer, I want stub generation to cost nothing on ordinary config reloads, so that editing config stays fast.
18. As a developer, I want generating the stubs to not trigger a Hammerspoon config reload, so that the autocomplete setup does not cause reload churn or loops.
19. As a developer opening the repo in VS Code, I want to be prompted to install the recommended extensions, so that the editor setup travels with the repo.
20. As a developer, I want the committed editor settings to apply automatically (StyLua as the Lua formatter, format-on-save, language-server formatter off, `hs` and busted globals known), so that the no-conflict configuration is reproducible.
21. As a developer, I want the autocomplete library path in committed settings to be portable (no hard-coded username, no broken symlink resolution), so that the same settings work for anyone who opens the repo at its real location.
22. As a developer, I want StyLua available through the existing `brew bundle` flow, so that installing it needs no new dependency type.
23. As a developer, I want luacheck installed into the project-local `lua_modules/` tree alongside busted, so that linting uses the same package mechanism as testing and pollutes nothing globally.
24. As a developer, I want `script/setup` to install and wire everything idempotently on a fresh clone, so that the tooling works the first time and re-running setup is safe.
25. As a developer, I want the EmmyLua.spoon generator vendored and committed, so that every machine runs identical generator code and setup works offline.
26. As a developer, I want a `make update-emmylua` target that re-vendors the latest generator, so that I can refresh it deliberately without remembering the upstream URL or procedure.
27. As a developer, I want the generated annotation files gitignored, so that machine-specific generated output never gets committed.
28. As the repo maintainer, I want CLAUDE.md's "Deliberate non-choices" reframed as a case-by-case principle, so that future agents stop reflexively avoiding tooling that improves the developer experience.
29. As the repo maintainer, I want the one genuinely informative non-choice (why `windows.lua` is hand-rolled rather than a stock window-manager Spoon) kept as recorded rationale, so that nobody regresses the custom layouts by swapping in a Spoon that cannot do them.
30. As the repo maintainer, I want an "Editor and tooling" section in CLAUDE.md documenting StyLua, LuaLS, luacheck, and the EmmyLua autocomplete stubs (including how to regenerate them), so that the setup is discoverable.
31. As the repo maintainer, I want the README to point a newcomer at the formatting, linting, and autocomplete setup, so that the entry point is documented without reading source.
32. As the repo maintainer, I want my own copyright line added to the LICENSE alongside the original author's, so that authorship reflects the fork accurately while honoring the MIT requirement to retain the original notice.
33. As the repo maintainer, I want the vendored Spoon to retain its MIT header and its upstream provenance recorded, so that the license obligation is met and future updates have a known source.
34. As a developer, I want the linter and formatter exposed as Makefile targets next to `make test`, so that I do not have to remember which script-vs-make convention applies to which task.

## Implementation Decisions

### Toolchain

- **StyLua** for formatting. Installed via Homebrew (`brew "stylua"` added to the Brewfile). The VS Code StyLua extension can manage its own binary, but installing through Homebrew keeps the CLI and the editor on one binary and fits the existing `brew bundle` flow.
- **lua-language-server (LuaLS)** for IntelliSense and diagnostics, delivered by the VS Code "Lua" extension (`sumneko.lua`). The language server binary ships inside the extension, so nothing extra is installed for it.
- **luacheck** for linting. Installed via LuaRocks into the project-local `lua_modules/` tree (`luarocks --tree=lua_modules install luacheck`), exactly like busted from the space-fn PRD. No global package pollution. Exposed as `make lint`.
- No selene. luacheck wins because it co-installs with busted in `lua_modules/` and understands busted's globals natively via its `--std` configuration.

### Tool separation (no conflicts)

The three tools are configured so each owns exactly one concern:

- StyLua owns all formatting.
- LuaLS owns IntelliSense and type/reference diagnostics, with its own formatter disabled (`Lua.format.enable = false`).
- luacheck owns logic linting only. Its formatting and whitespace checks are switched off (notably `max_line_length = false`) so it never contradicts StyLua. This is the luacheck analog of `eslint-config-prettier`.

### StyLua configuration

A `stylua.toml` at the repo root matched to the existing house style, so a full reformat of the current tree is effectively a no-op:

```toml
column_width = 100
indent_type = "Spaces"
indent_width = 2
quote_style = "AutoPreferSingle"
```

(The existing files use 2-space indentation and single quotes exclusively, with lines up to roughly 100 columns. This config preserves that.)

### luacheck configuration

A `.luacheckrc` at the repo root that:

- Declares `hs` as a read global so `hs.*` references are not flagged.
- Applies busted's standard set to `spec/` so test globals (`describe`, `it`, `assert`, and friends) are recognized.
- Disables formatting and whitespace diagnostics, including setting `max_line_length = false`, so StyLua owns line length and spacing.

### Editor configuration (committed)

- **`.vscode/extensions.json`** recommends `sumneko.lua` and `JohnnyMorganz.stylua`. VS Code prompts to install on open. It cannot silently auto-install; clicking "Install" is the one unavoidable manual step.
- **`.vscode/settings.json`** sets, at minimum:
  - StyLua as the default formatter for Lua, with format-on-save enabled for Lua.
  - `Lua.format.enable = false` so the language server does not also format.
  - `hs` declared as a known global, and busted's globals recognized for `spec/`.
  - A `package.path`-equivalent so `require('keyboard.…')` resolves from `spec/` (mirroring the space-fn PRD's `.busted` entry of `./hammerspoon/?.lua`), so go-to-definition works across spec-to-source.
  - `Lua.workspace.library` pointing at the EmmyLua annotations directory using a workspace-relative path (`${workspaceFolder}/hammerspoon/Spoons/EmmyLua.spoon/annotations`). This is portable (no hard-coded username) and avoids symlink resolution, which LuaLS handles poorly, provided the editor is opened at the repo's real location.

### EmmyLua.spoon vendoring and autocomplete

- **Vendor** EmmyLua.spoon into the repo (committed) at `hammerspoon/Spoons/`, with its MIT header intact and its upstream provenance (source URL and commit) recorded. Vendoring is chosen over fetch-at-setup so every machine runs identical generator code, setup is offline-safe, and there is no per-machine generator drift.
- The generator's output path is hardcoded inside its own bundle (it writes to `hs.spoons.resourcePath("annotations")`, i.e. `~/.hammerspoon/Spoons/EmmyLua.spoon/annotations`). This is not configurable without patching the source, and we do not patch it. The vendor-and-symlink layout makes the hardcoded path work for us: `script/setup` symlinks `~/.hammerspoon/Spoons/EmmyLua.spoon` to the vendored copy in the repo, so the generator's writes pass through the symlink and physically land inside the repo at a real path. The editor reads them at the real repo path, with no symlink on the read side.
- **Generation trigger**: the generator runs as a side effect of the Spoon's `:init()`, which Hammerspoon invokes on load. So a guarded `pcall(hs.loadSpoon, 'EmmyLua')` in `init.lua` is all that is needed. There is no separate `:start()` or `:generate()` call.
- **No custom version guard.** The generator already guards itself on file modification times (it stores mtimes in `annotations/timestamps.json` and regenerates only when Hammerspoon's docs JSON changes, which is when Hammerspoon is upgraded). So loading it on every reload is cheap (a stat plus a small JSON read, then short-circuit), and the stubs refresh automatically after an upgrade. We do not build our own `hs.processInfo.version` guard.

### init.lua changes

- Add a guarded `pcall(hs.loadSpoon, 'EmmyLua')` so a missing Spoon is a no-op rather than an error.
- Make the reload watcher ignore generated annotation files. The existing `reloadOnLua` callback reloads on any `.lua` change under `hs.configdir` and the keyboard-symlink target. The generated annotation files are `.lua` files that land inside that watched target, so without a guard, generation would trigger a reload. The decision is to filter out files under the EmmyLua `annotations/` directory in `reloadOnLua`. The generator's own mtime guard means regeneration only happens after a Hammerspoon upgrade, so this filter is belt-and-suspenders against any reload churn or loop, and it removes any dependence on load-ordering relative to the watcher (the watcher is created early in `init.lua`).

### Makefile targets

Added to the `Makefile` that the space-fn PRD introduces:

- `make fmt` formats the repo with StyLua.
- `make fmt-check` checks formatting without writing (non-zero exit on drift).
- `make lint` runs luacheck from `lua_modules/`.
- `make update-emmylua` re-vendors the latest upstream EmmyLua.spoon, backed by a small `script/` helper that encodes the canonical source URL and target path. This delegates to a script the same way `make install` delegates to `script/setup`.

### setup script changes

- `brew bundle` (already present) installs StyLua via the new Brewfile entry.
- Add a `luarocks --tree=lua_modules install luacheck` line alongside the space-fn PRD's busted install. Idempotent.
- Add a step that symlinks `~/.hammerspoon/Spoons/EmmyLua.spoon` to the vendored copy in the repo, mirroring the existing pattern that symlinks `hammerspoon/` to `~/.hammerspoon/keyboard`. Create `~/.hammerspoon/Spoons/` first if needed. The fetch is failure-tolerant in spirit: because the Spoon is vendored, there is no network dependency here at all.

### One-time baseline format

Run StyLua once across the whole repo and commit the result as a clean baseline. Because the config matches the existing style, this should be a near-no-op. The diff is shown to the maintainer before committing.

### Brewfile changes

Add `brew "stylua"`. (The space-fn PRD already adds `brew "luarocks"` and `brew "lua"`.)

### gitignore changes

Add the EmmyLua annotations directory (`hammerspoon/Spoons/EmmyLua.spoon/annotations/`) so generated, machine-specific output is never committed. (The space-fn PRD already adds `lua_modules/`.)

### CLAUDE.md changes

- Reframe the "Deliberate non-choices" section from a list of prohibitions into a single case-by-case principle: dependencies are evaluated on their merits, balancing not-invented-here against needless complexity, favoring good developer experience and current best practices.
- Keep only the entry that carries real technical rationale: why `windows.lua` is hand-rolled rather than a stock window-manager Spoon (it supports custom layouts like `left40`, `right60`, `centerWithFullHeight` that those Spoons do not, so swapping one in would be a regression). Reframe it as recorded rationale, not dogma. Drop the purely dogmatic entries (such as the ReloadConfiguration-Spoon note).
- Under the case-by-case principle, the vendored EmmyLua.spoon needs no special carve-out. It is documented as a dev-only tooling Spoon for editor autocomplete.
- Add an "Editor and tooling" section documenting StyLua, LuaLS, luacheck, the no-conflict tool separation, and the EmmyLua autocomplete stubs, including how they regenerate and how to refresh the generator (`make update-emmylua`).
- This composes with the space-fn PRD's own CLAUDE.md edits (which remove the package-manager non-choice and add a testing section). This PRD layers the editor/tooling section on top and adjusts the Spoons framing.

### README changes

Add a short pointer to the tooling: format with `make fmt`, lint with `make lint`, and that opening the repo in VS Code prompts for the recommended extensions and gives `hs.*` autocomplete. Keep it brief; this is a personal config, not a public library. (The space-fn PRD fills in the README's overview and `make install` / `make test` sections; this adds the formatting/linting/autocomplete lines.)

### LICENSE changes

Add the current maintainer's copyright line alongside the original author's, both under the existing MIT terms:

```
Copyright (c) 2013 Jason Rudolph (http://jasonrudolph.com)
Copyright (c) 2022-2026 Pierre Spring <pierre.spring@caillou.ch>
```

The original notice is retained as MIT requires.

## Testing Decisions

This PRD is configuration and glue. There is no unit-testable logic, no deep module with a behavioral interface, so it ships **no automated tests**. (Contrast the space-fn PRD, whose pure state-machine engine is worth unit-testing with busted.) Verification is manual and command-based.

Manual verification checklist:

- `make fmt-check` passes on a clean tree (the baseline pass made it conformant).
- `make fmt` is idempotent: running it twice produces no diff on the second run.
- `make lint` runs and reports only logic-level findings; `hs.*` references and busted globals in `spec/` are not flagged as undefined.
- Editing a Lua file and saving in VS Code formats it via StyLua, and the language server does not also reformat or fight the result.
- Typing `hs.window.` in the editor offers autocomplete with signatures, confirming the EmmyLua stubs are generated and the library path resolves.
- Saving a config file does not trigger an extra Hammerspoon reload caused by annotation generation (the `reloadOnLua` filter works).
- A fresh `script/setup` (or `make install`) on a clean checkout produces a working formatter, linter, and autocomplete without manual steps beyond accepting the VS Code extension prompt.
- After a Hammerspoon upgrade and reload, the stubs reflect the new version (spot-check a newly added or changed API if convenient).

No prior art for tests exists in this repo; the space-fn PRD introduces the first test suite, and this work deliberately adds none of its own.

## Out of Scope

- **CI / GitHub Actions.** This is a personal repo on one machine. No automated formatting or lint gate in CI.
- **selene.** luacheck is the chosen linter; selene is not added.
- **Pre-commit hooks.** No git hook to enforce `make fmt-check` / `make lint` before commit. Could be added later.
- **Patching EmmyLua.spoon to make its output path configurable.** We use the symlink layout instead and leave the vendored source unmodified (beyond keeping it current via `make update-emmylua`).
- **A custom Hammerspoon version guard for stub regeneration.** The generator's own mtime guard is sufficient.
- **The dedicated `sisoe24/hammerspoon-vscode` extension.** Autocomplete is provided via LuaLS plus EmmyLua stubs, not a third extension.
- **Reformatting or refactoring source beyond the one-time baseline format.** The baseline pass aside, files change only as the wiring requires.
- **Rockspec / publishing.** luacheck is consumed via LuaRocks, not published. No `.rockspec`.
- **Anything owned by the space-fn PRD.** The `Makefile`, LuaRocks/`lua_modules` foundation, busted, `spec/`, the test-infra CLAUDE.md section, and the README overview are created there. This PRD only adds to them.

## Further Notes

### Sequencing

This PRD assumes the space-fn PRD has landed first. It depends on that PRD's `Makefile` (to hang `fmt` / `fmt-check` / `lint` / `update-emmylua` on), its LuaRocks + `lua_modules/` setup (to install luacheck the same way as busted), and its CLAUDE.md and README rewrites (which this PRD extends rather than duplicates). If the order is ever reversed, the overlapping files (CLAUDE.md, Brewfile, .gitignore, script/setup, README, Makefile) would need manual reconciliation.

### Why vendor the generator instead of fetching it

The autocomplete stubs are generated from the live installed Hammerspoon API, so the stubs themselves cannot drift from the installed version. The only thing that could vary per machine is the generator code. Vendoring it (committing it) removes that variation, makes `script/setup` offline-safe, and removes a network failure mode from a `set -e` setup script. The cost is a manual, deliberate refresh of the generator, which is rare and handled by `make update-emmylua`.

### On the "will they fight" concern

The original motivating worry was the eslint-vs-prettier conflict. It is avoided by strict separation of concerns: StyLua formats, luacheck lints logic with all formatting checks disabled, and the language server's formatter is turned off. The only tool that formats is StyLua.

### Symlinks and LuaLS

LuaLS resolves poorly through symlinked source roots. This is handled by opening the repo at its real location (`~/repos/keyboard`, not the `~/.hammerspoon/keyboard` symlink) and by pointing `Lua.workspace.library` at the real workspace-relative annotations path. The symlink exists only on the Hammerspoon write side, not the editor read side.

### License facts

The repo's LICENSE is already MIT (Copyright 2013 Jason Rudolph). EmmyLua.spoon is also MIT (its `init.lua` declares the license). MIT permits vendoring as long as the original copyright and permission notice are retained, which is satisfied by committing the Spoon files with their header intact.

## Post-implementation notes

### 2026-05-30: StyLua config landed as spaces-only defaults (not the 4-setting single-quote config)

The "StyLua configuration" section above specifies a 4-setting `stylua.toml`
(`column_width = 100`, `indent_type = "Spaces"`, `indent_width = 2`,
`quote_style = "AutoPreferSingle"`). The shipped config (maintainer-approved)
keeps only the two indentation settings and otherwise follows StyLua defaults:

```toml
indent_type = "Spaces"
indent_width = 2
```

This means double quotes (StyLua default) rather than single, and a 120-column
width (StyLua default) rather than 100 — the modern Lua/Neovim-ecosystem
convention. The one-time baseline format pass therefore re-quoted existing
strings, so it was not the near-no-op the section above anticipated; the diff
was reviewed and committed deliberately. The vendored EmmyLua.spoon is excluded
from formatting via a root `.styluaignore` (`hammerspoon/Spoons/`, plus
`lua_modules/` defensively) so it stays byte-for-byte upstream-exact. The
historical decision text above is left unchanged; this note is the current
spec.
