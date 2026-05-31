# Dev Tooling Hardening (enforcement, engine types, non-Lua coverage)

## Problem Statement

The repo now has a real Lua toolchain (StyLua, luacheck, LuaLS + EmmyLua autocomplete, busted) from the space-fn and lua-dev-tooling PRDs. But the tooling is all *opt-in* and *partial*, and this repo is driven as hard by Claude Code subagents as by me typing. Two gaps follow from that:

- **Nothing enforces the checks.** `make fmt-check`, `make lint`, and `make test` exist, but a change — especially one a subagent authored — can land on `master` having run none of them. I review diffs, not the reasoning behind them, so a broken Engine transition, a forgotten `local`, or format drift can slip through. For a careful solo human this is tolerable; as a guardrail against agent-authored changes it is a hole.
- **The tooling stops at the Lua source.** The Engine's whole contract is stringly-typed (Event tokens and Action tokens are bare strings), so a typo like `'space-dwon'` silently falls through to a default and disappears — exactly the kind of mistake a TS developer never tolerates and an agent can easily introduce. Meanwhile `script/setup` and `script/update-emmylua` — the fragile install path, with its documented `cliInstall` half-states and `PATH` repair dance — are shell, which StyLua and luacheck do not touch at all. And non-Lua files (markdown PRDs, `lefthook.yml`, toml) have no cross-editor formatting baseline.

The result is a toolchain that is good at *offering* quality checks and bad at *guaranteeing* them, with the highest-typo-risk surface (the Engine token protocol) and the most fragile surface (the install scripts) both unguarded.

## Solution

Harden the existing toolchain along two axes — enforce what we already check, and extend coverage to the surfaces currently missed — while holding to the repo's case-by-case, minimal-ceremony principle. Each addition earns its place; nothing is added reflexively.

- **Enforce at commit time with lefthook.** A `lefthook`-managed pre-commit hook runs `fmt-check`, `lint`, `test`, and shellcheck before a change is recorded. The workflow is direct commits to `master` with no PR gate, so the commit boundary — not CI — is where an agent or I am about to record a change, and therefore the right place to catch a regression. CI is deliberately not added (see `docs/adr/0002-enforce-checks-via-lefthook-not-ci.md`). lefthook is chosen over a raw `.git/hooks` script or the Python `pre-commit` framework for the declarative, managed, husky-like developer experience, installed through Homebrew to match how the repo already adopted StyLua.
- **Type the Engine's token protocol.** Add EmmyLua annotations (`---@enum`, `---@class`, `---@param`/`---@return`) to `space-fn-engine.lua` so the Event tokens, Action tokens, action shapes, and keymap-entry shape become checked, autocompleted types in the editor. LuaLS diagnostics are set to a moderate level — enough to flag a bad token string or an undefined field, but not so strict that the Engine's `setmetatable`-based object pattern produces a wave of false positives. This is comments and an editor setting; no Engine behavior changes.
- **Guard the shell.** Add shellcheck (via Homebrew) over `script/*`, wired into the same pre-commit hook, so the documented-fragile install path gets a static guard.
- **Round out the non-Lua files and ergonomics.** A `.editorconfig` gives every editor (not just VS Code) an indent/charset/newline baseline for the files StyLua ignores. LuaRocks installs are pinned to exact versions so a fresh clone cannot pull a luacheck whose diagnostics shift and silently break the new hook. Small `make` ergonomics (`reload`, `console`) and luacov coverage of the existing Engine spec round it out.

This work assumes the space-fn and lua-dev-tooling PRDs have landed (they have): the `Makefile`, `lua_modules/` tree, busted, luacheck, StyLua, the `.vscode/` config, and the EmmyLua autocomplete all already exist. This PRD layers enforcement and type coverage on top of that foundation rather than recreating any of it.

## User Stories

1. As a maintainer reviewing an agent-authored diff, I want the formatting, lint, and test checks to have already run before the change was committed, so that I am reviewing code that is known to pass rather than trusting that someone ran the checks.
2. As a maintainer, I want a forgotten `local` (an accidental global) to block the commit, so that the single most common Lua footgun cannot reach `master`.
3. As a maintainer, I want a broken Engine state transition to fail `make test` inside the pre-commit hook, so that a regression in the Roll-vs-Chord logic is caught before it lands.
4. As a maintainer, I want StyLua format drift to block the commit, so that the formatted baseline stays clean without me remembering to run `make fmt`.
5. As a maintainer, I want the pre-commit hook installed automatically by `script/setup` on a fresh clone, so that enforcement travels with the repo and needs no manual git-hook wiring.
6. As a maintainer, I want the hook managed by a declarative `lefthook.yml` rather than a hand-rolled shell script, so that the hook configuration is the husky-like experience I know from JS and is easy to read and change.
7. As a maintainer, I want lefthook installed through `brew bundle`, so that adding it introduces no new dependency mechanism beyond the existing Homebrew flow.
8. As a maintainer, I want the hook to run the whole suite (not staged-file-filtered), so that the configuration stays simple — the suite runs in under two seconds on a repo this small, so filtering buys nothing.
9. As a maintainer, I want the option to bypass the hook with `git commit --no-verify` to remain available, so that an intentional work-in-progress commit is never fully blocked.
10. As a maintainer, I want CI deliberately not added, so that the repo does not grow a notification-only GitHub Actions gate that cannot prevent anything on a direct-to-`master` workflow.
11. As a developer new to Lua, I want the Engine's Event tokens to be a checked enum, so that a mistyped token like `'space-dwon'` is underlined in the editor instead of silently falling through to a default.
12. As a developer, I want the Engine's Action tokens to be a checked enum, so that the Adapter and the spec both speak a typo-proof protocol.
13. As a developer, I want the action objects the Engine returns (e.g. `emit-key`, `emit-remap`) to have declared shapes, so that the editor tells me which fields each action carries.
14. As a developer, I want the keymap-entry shape declared, so that adding or changing a mapping has editor support for its structure.
15. As a developer, I want `new()` and `advance()` annotated with their parameter and return types, so that the Engine's public interface is self-documenting and autocompleted.
16. As a developer, I want LuaLS diagnostics set to a moderate level, so that I get useful type and reference warnings without a flood of false positives from the Engine's `setmetatable` object pattern.
17. As a developer, I want the annotations to change no Engine behavior, so that the existing spec suite continues to pass unchanged and the Adapter is unaffected.
18. As a maintainer, I want shellcheck run over `script/setup` and `script/update-emmylua`, so that the fragile install path — with its known `cliInstall` half-states and `PATH` repair logic — has a static guard against shell mistakes.
19. As a maintainer, I want shellcheck installed via `brew bundle` and run inside the pre-commit hook, so that a shell mistake in a setup script blocks the commit the same way a Lua mistake does.
20. As a developer using an editor other than VS Code, I want a `.editorconfig` defining indent, charset, and final-newline rules, so that the non-Lua files StyLua ignores (markdown, `lefthook.yml`, toml) stay consistent regardless of editor.
21. As a maintainer, I want busted and luacheck pinned to exact versions in `script/setup`, so that a fresh clone installs the same tool versions and a luacheck diagnostic change cannot silently start failing the pre-commit hook.
22. As a maintainer, I want a `make reload` target wrapping `hs -c "hs.reload()"`, so that I can force a Hammerspoon reload from the terminal without remembering the incantation.
23. As a maintainer, I want a `make console` target to open the Hammerspoon console, so that jumping to the debug log is one command.
24. As a maintainer, I want luacov coverage of the existing Engine spec via a `make` target, so that I can see which Engine state transitions the spec actually exercises — directly supporting the ADR-0001 practice of pushing logic into the Engine and confirming it is genuinely tested.
25. As a maintainer, I want luacov's generated output gitignored, so that machine-specific coverage reports are never committed.
26. As a maintainer, I want shellcheck folded into `make lint`, so that running the linter locally checks both Lua and shell from one command and matches what the hook runs.
27. As a maintainer, I want the "Editor and tooling" section of CLAUDE.md to document the enforcement model, the shellcheck addition, and the Engine annotation rationale (engine-only, moderate diagnostics, and why), so that the setup is discoverable and a future agent does not "fix" the deliberate choices.
28. As a maintainer, I want the two decisions with real lock-in (keep-the-Adapter-thin, lefthook-not-CI) recorded as ADRs, so that the non-obvious choices survive and are not re-litigated. (Both already written this session.)

## Implementation Decisions

### Enforcement via lefthook (see ADR 0002)

- A `lefthook.yml` at the repo root defines a `pre-commit` stage running, as parallel commands: `fmt-check` (StyLua check), `lint` (luacheck + shellcheck), `test` (busted), and `shellcheck` over `script/*`. The exact grouping (whether shellcheck is its own command or folded into the `lint` command) is left to implementation, but every check that gates a commit must be represented.
- The whole suite runs, not a staged-file subset. The suite is sub-two-seconds on this repo, so lint-staged-style filtering is omitted as needless complexity.
- `brew "lefthook"` is added to the Brewfile.
- `script/setup` runs `lefthook install` idempotently after `brew bundle`, so the git hook is wired on a fresh clone with no manual step. Re-running setup is safe.
- CI is explicitly not added. Rationale: direct-to-`master` workflow means CI-on-push runs after a change has already landed; it notifies but cannot prevent. The commit boundary is the correct gate. This refines the space-fn and lua-dev-tooling PRDs' "CI out of scope" from "no enforcement" to "local enforcement only."

### Engine annotations (LuaLS)

- Annotate `space-fn-engine.lua` only. The Adapter (`space-fn.lua`) and `windows.lua` are not annotated in this PRD — the Engine is where the type *is* the design (the Event-token / Action-token protocol) and where the contract is stable and spec-pinned, so annotation drift risk is lowest and payoff highest.
- Declare the Event tokens (`space-down`, `space-down-autorepeat`, `space-up`, `key-down`, `key-up`, `timer-fire`) as a `---@enum`, and the Action tokens (`emit-space`, `emit-key`, `emit-remap`, `suppress`, `passthrough`, `start-timer`, `cancel-timer`) as a `---@enum`.
- Declare `---@class` shapes for the action objects that carry payload fields (e.g. the `emit-key` action's `key`/`mods`, the `emit-remap` action's `remap`/`physMods`) and for a keymap entry.
- Annotate `M.new(opts)` and `M:advance(event, payload)` with `---@param`/`---@return`.
- No behavior change. Whether the Engine merely *documents* the tokens via annotations or also *references* the enum tables in its branch conditions is an implementation detail, provided the existing spec passes unchanged and no token is rejected at runtime (runtime token validation was explicitly considered and deferred — see Out of Scope).
- Set LuaLS diagnostics in `.vscode/settings.json` to a moderate level: enough to surface undefined fields and bad token strings, but not the strictest setting, which produces false positives against the `setmetatable({}, { __index = M })` object pattern. The precise diagnostic keys are an implementation detail; the intent is "useful, low-noise."

### shellcheck

- `brew "shellcheck"` added to the Brewfile.
- Run over `script/setup` and `script/update-emmylua` (and any future `script/*`).
- Folded into `make lint` so the local lint command covers Lua and shell, and run inside the pre-commit hook.
- No project config file needed; shellcheck's defaults are accepted. Any genuinely-needed suppressions are inline `# shellcheck disable=` directives at the offending line, not a blanket config.

### Non-Lua files and ergonomics

- A root `.editorconfig` sets, at minimum, 2-space indentation, UTF-8, final newline, and trailing-whitespace trim for the file types StyLua does not own (markdown, yaml, toml). It intentionally does not fight StyLua over `.lua` files — StyLua remains the sole Lua formatter.
- `script/setup`'s LuaRocks install lines pin exact versions for busted and luacheck (e.g. `luarocks --tree=lua_modules install busted <ver>`), so installs are reproducible and a diagnostic-changing luacheck upgrade cannot silently break the hook. No `.rockspec` is introduced; pinning lives in the install command.
- `Makefile` gains `reload` (`hs -c "hs.reload()"`), `console` (open the Hammerspoon console), and a coverage target running busted with luacov.
- luacov's generated output (e.g. `luacov.stats.out`, `luacov.report.out`) is added to `.gitignore`.

### Documentation

- CLAUDE.md's "Editor and tooling" section is extended to document: the lefthook pre-commit enforcement model and the deliberate no-CI stance (pointing at ADR 0002), the shellcheck addition, and the Engine annotation rationale (engine-only scope, moderate diagnostics, and why strict is avoided). The annotation rationale lives here rather than in an ADR because annotations are trivially reversible.
- `CONTEXT.md` (glossary: Engine, Adapter, Event token, Action token, Roll, Chord) and the two ADRs (`0001-keep-space-fn-adapter-thin`, `0002-enforce-checks-via-lefthook-not-ci`) were written during the design session and are referenced, not recreated, here.

## Testing Decisions

This PRD ships **no new automated tests**, consistent with `docs/adr/0001-keep-space-fn-adapter-thin.md` (the Engine is the tested surface; the Adapter is verified by using the keyboard, and we deliberately do not mock `hs`) and with the lua-dev-tooling PRD (pure configuration ships no tests).

- A good test in this repo describes user-visible Engine behavior as a list of Event tokens in and Action tokens out (the existing `spec/space-fn-engine_spec.lua` is the prior art and the pattern). This PRD adds none because it introduces no new behavioral logic: the annotations are checked by LuaLS at edit time, enforcement is exercised by the pre-commit hook itself, and luacov *measures* the existing Engine spec rather than adding to it.
- Runtime token validation (making the Engine reject an unknown Event/Action token and asserting that with new busted cases) was considered and deferred: it is a behavior change beyond the annotation-only scope decided for this work. See Out of Scope.

Verification is manual and command-based:

- `make lint` reports Lua and shell findings; a deliberately broken shell line in a `script/*` file is flagged.
- A staged commit with a StyLua drift, a luacheck finding, a failing Engine spec, or a shellcheck finding is blocked by the pre-commit hook; `--no-verify` bypasses it.
- A fresh `script/setup` on a clean clone installs lefthook, pins the rock versions, and wires the hook with no manual step.
- In the editor, a mistyped Event/Action token string and an undefined action field are underlined; the `setmetatable` object pattern does not produce a wave of false positives.
- `make reload`, `make console`, and the coverage target each work; coverage output is gitignored.

## Out of Scope

- **CI / GitHub Actions.** Deliberately excluded (ADR 0002). Enforcement is local, at the commit boundary.
- **Runtime token validation in the Engine.** Making the Engine reject an unknown Event/Action token (rather than falling through to its default) and adding busted cases for it is a behavior change beyond annotation scope. Could be a future PRD; not this one.
- **Annotating the Adapter or `windows.lua`.** Annotation is scoped to the Engine's token protocol. Other modules are left unannotated.
- **Strict LuaLS diagnostics.** Moderate level only, to avoid `setmetatable`-OO false positives.
- **lint-staged-style staged-file filtering.** Unnecessary on a sub-two-second suite.
- **A `.rockspec` or LuaRocks publishing.** Versions are pinned in the install command; no manifest is introduced.
- **The Python `pre-commit` framework and a raw `.git/hooks` script.** lefthook is the chosen manager (ADR 0002).
- **Markdown or prose linting (markdownlint, prettier-for-md).** `.editorconfig` covers whitespace baselines; full prose linting is not added.
- **A runtime `strict.lua` global guard.** luacheck already flags accidental globals statically, and the pre-commit hook now runs luacheck on every commit, so a runtime guard would be redundant and risks breaking the live config via its allowlist.
- **An `hs` test shim / Adapter unit tests.** Excluded by ADR 0001.
- **Re-running or modifying the space-fn / lua-dev-tooling PRDs.** Their outputs are the foundation this PRD builds on; it only adds to them.

## Further Notes

### Sequencing

This PRD assumes the space-fn and lua-dev-tooling PRDs have landed — verified at authoring time: `Makefile`, `lua_modules/`, busted, luacheck, StyLua, `.vscode/`, the EmmyLua autocomplete Spoon, and both `script/setup` and `script/update-emmylua` all exist. Every "modify" target therefore exists; the only genuinely new files are `lefthook.yml` and `.editorconfig`. There is no remaining cross-PRD dependency to wait on.

### Why local enforcement and not CI

Recorded in full in ADR 0002. In short: the repo commits directly to `master`, so a push-triggered CI run reports on a change that has already landed — it cannot gate. The pre-commit hook gates at the exact point an agent or human records the change, which is what the agent-guardrail half of this work needs. The PRDs' original "CI out of scope" is preserved; what changes is that "no enforcement" becomes "local enforcement."

### Why the Engine and not the Adapter for types

The Engine's public surface *is* its type: an Event-token protocol in, an Action-token protocol out. That makes it the highest-leverage place to add checked types (typos become editor errors) and the lowest-drift place (the contract is stable and pinned by the spec). The Adapter is intentionally thin (ADR 0001) and its bugs are obvious at runtime, so annotating it earns little. This mirrors the same engine-first instinct recorded in ADR 0001 for testing.

### Posture

The design session weighted human developer-experience and agent-guardrail value equally, with the discipline that each item still had to clear the repo's minimal-ceremony bar. Items that did not — a runtime `strict.lua` guard, CI, an `hs` test shim, strict diagnostics, staged-file filtering — were dropped for stated reasons rather than carried in for completeness.
