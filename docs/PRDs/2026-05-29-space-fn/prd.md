# Space-as-modifier (space-fn)

## Problem Statement

I want to use the spacebar as a held-modifier to reach navigation keys (arrows, delete, tab cycling) without leaving the home row. I built three earlier attempts at this (`hammerspoon/super.lua`, `super-new.lua`, `super-backup.lua`) and stopped using all of them because each tripped me up while typing fast.

The specific failure: typing a phrase like "and i" — where my finger releases the spacebar slightly *after* pressing the next letter — caused the next letter to be intercepted and remapped instead of being typed. Once that started happening a few times a day, the loss-of-trust outweighed the benefit and I disabled the whole thing.

Beneath that surface failure, all three attempts share the same root cause: they decide tap-vs-hold from the *press* order alone (was space-down first? did the next key arrive within Nms?). Press-order can't distinguish "I'm chording" from "I'm rolling fingers off space onto the next key," because both look identical at press time. The decision can only be made reliably after a *release* event arrives.

The earlier attempts also accumulated subsidiary problems: missing keyUp handlers (state never clears), buffer replay logic that was sketched but never written, key maps that were commented out, a typing-burst heuristic that's a brittle workaround for the press-order misdiagnosis, and a "training mode" that fought the implementation rather than fixing it. The result is three half-finished scratchpad files that don't compose into a usable feature, none currently wired into Hammerspoon.

There is also a meta-problem: this is the first piece of code in the repo that warrants tests, and the repo currently has no test infrastructure. CLAUDE.md explicitly disallows package managers beyond Homebrew, which precludes idiomatic Lua tooling (LuaRocks → busted). That stance was a deliberate non-choice for a repo that previously held simple glue code; once we have a non-trivial state machine, that stance becomes a constraint that costs more than it saves.

## Solution

Replace the three scratchpads with a single, tested implementation built around a **release-order state machine**.

The core observation: the failure case ("and i") and the success case ("intentional chord") differ in *which key releases first*, not in any property of the press sequence. We decide nothing at press time — we buffer, and decide at the first release event:

- If the chord-candidate key releases *before* space → user chorded; emit the remapped key.
- If space releases *before* any chord-candidate → user rolled off space onto the next key; emit literal space, then replay the buffered key literally.

This single rule eliminates the entire class of typing-burst false positives without needing typing-burst detection. We add one supporting timer (750ms long-hold commit) for the case where space is held with no other key — change of mind, hold-then-release should not emit space.

The implementation also unifies a second intent signal — **the keymap itself**: if a key pressed during the pending window is *not* in the keymap, that's strong evidence the user is typing, not chording. We abort the pending state immediately on unmapped-key-down (emit literal space + literal key) rather than waiting for release order. Mapped keys still wait for the release-order verdict.

The new code lives in two files inside `hammerspoon/`:

- `space-fn-engine.lua` — pure Lua state machine. Inputs are abstract event tokens (`space-down`, `key-down(k, mods)`, `key-up(k)`, `space-up`, `timer-fire`). Outputs are abstract action tokens (`emit(k, mods)`, `suppress`, `start-timer`, `cancel-timer`). No `hs.*` dependencies; fully unit-testable.
- `space-fn.lua` — thin adapter. Owns the `hs.eventtap`, translates real Hammerspoon events into engine inputs, dispatches engine actions back out (`hs.eventtap.keyStroke`, suppression, `hs.timer.doAfter`). Also owns the windows-mode-disabled hook.

The three scratchpad files are deleted in the same commit.

Alongside the feature, we introduce **testing infrastructure** so the engine's release-order logic is verified by spec rather than by squinting at it. busted (the de facto Lua test framework) is installed via LuaRocks into a project-local `lua_modules/` directory, similar to npm's `node_modules`. Tests live in `spec/` at the repo root using busted's standard `_spec.lua` convention. A Makefile exposes `make install`, `make test`, and `make test-watch` as the public entry points.

CLAUDE.md is updated to reflect the new posture: LuaRocks and busted are now part of the toolchain; the previous "no package manager beyond Homebrew" stance is removed. The README — currently empty beyond a heading — is filled in to point newcomers (or future-me) at `make install` and `make test`.

## User Stories

1. As a fast typist, I want to type "and i" with rolling fingers and see the literal characters "and i" appear, so that my muscle memory for typing isn't punished by the modifier layer.
2. As a fast typist, I want to type any phrase where space precedes a letter (e.g., "the apple", "is in") with finger-rolling, so that no letter is silently lost or remapped.
3. As a keyboard user, I want to tap space alone and see a literal space, so that the modifier layer is invisible during ordinary typing.
4. As a keyboard user, I want to hold space + j and have it act as left-arrow, so that I can navigate without leaving the home row.
5. As a keyboard user, I want the same for space + i (up), space + k (down), space + l (right), so that all four arrows are home-row reachable.
6. As a keyboard user, I want space + h to act as delete, so that I can erase the previous character without reaching for the delete key.
7. As a keyboard user, I want space + u and space + o to cycle browser/editor tabs (cmd+shift+[ / cmd+shift+]), so that tab navigation stays on the home row.
8. As a keyboard user, I want space + v to emit ctrl+opt+v (paste-and-match-style or whatever I've bound it to elsewhere), so that I keep that habit.
9. As a keyboard user, I want to hold space + j and have left-arrow auto-repeat, so that holding the chord scans through the document the way real arrow keys do.
10. As a keyboard user, I want space + cmd + j (with cmd already physically held) to act as cmd + left-arrow, so that I can compose space-fn with macOS modifier shortcuts.
11. As a keyboard user, I want space + shift + j to act as shift + left-arrow (select character left), so that selection by chord works.
12. As a keyboard user, I want to use cmd+shift+space+j as cmd+shift+left-arrow (select word left), so that combinatorial chord usage works for selection.
13. As a keyboard user, I want cmd + space alone to still open Spotlight, so that an existing system shortcut is not broken by the modifier layer.
14. As a keyboard user, I want to press space, change my mind, hold it for a second or two without pressing another key, then release space, and have *no* space character emitted, so that aborted chord attempts don't pollute my text.
15. As a keyboard user, I want a single short tap of space (well under 750ms) with no other key to emit a literal space, so that real space taps are unambiguous.
16. As a keyboard user, I want to press space then a key that isn't in the modifier map (e.g., space + q, space + z) and have it behave as "tap-space then type the letter," so that typo-style chord attempts don't disappear silently.
17. As a keyboard user, I want, once a chord has been committed during a space-hold, subsequent unmapped keys in the same hold to be silently swallowed, so that muscle-memory overshoot during navigation doesn't leak random characters into my document.
18. As a keyboard user, I want to chord space + multiple keys (e.g., space + j + k) and have whichever key I release first decide the verdict for the whole press, so that multi-key chord sequences feel decisive.
19. As a keyboard user, I want, once I've completed a chord during a hold, further keys in that same hold to remap *immediately* with no buffering delay, so that fast multi-action navigation feels responsive.
20. As a Window Layout Mode user, I want the spacebar to behave exactly as it does today inside windows-mode (center window with full height, exit mode), so that this work doesn't regress windows-mode behavior.
21. As a Window Layout Mode user, I want chord keys (`space + h`, `space + u`, etc.) pressed inside windows-mode to not leak synthetic events (delete, cmd+shift+[) into the focused app behind windows-mode.
22. As a one-handed user, I want the actual arrow keys to act the same as `i / j / k / l` inside windows-mode, so that I can perform window operations with only my right hand when needed.
23. As the repo's maintainer, I want a single Makefile entry point for setup and tests, so that I don't have to remember which script-vs-make convention applies to which task.
24. As the repo's maintainer, I want `make test` to run an isolated suite against the engine, so that I can change the state machine and gain confidence within seconds.
25. As the repo's maintainer, I want `make test-watch` available, so that I can iterate on engine changes with sub-second feedback.
26. As the repo's maintainer, I want tests written as user-visible scenarios ("space + j released first emits left-arrow"), so that they double as living documentation of the intended behavior.
27. As the repo's maintainer, I want test files to be cleanly separated from source under `spec/`, so that the Hammerspoon pathwatcher does not reload on test edits.
28. As the repo's maintainer, I want `script/setup` to install the test toolchain (LuaRocks + busted into `lua_modules/`) idempotently on a fresh clone, so that the setup-then-test loop works the first time.
29. As the repo's maintainer, I want the README to point a newcomer (or future-me) at `make install` and `make test`, so that the entry point is documented without needing to read source.
30. As the repo's maintainer, I want CLAUDE.md updated to reflect that LuaRocks and busted are now part of the toolchain, so that future agents stop reflexively avoiding them.
31. As a developer debugging unexpected behavior, I want one-command access to a verbose trace of state transitions, so that I can diagnose "why did space + j do that?" without restarting Hammerspoon.
32. As a developer, I want the engine and the eventtap adapter as separate files, so that swapping the I/O surface (or testing the engine standalone) doesn't require disentangling them.
33. As a developer, I want the keymap defined as plain data, so that adding or changing a mapping is a one-line edit with no logic touched.

## Implementation Decisions

### Modules

- **`hammerspoon/space-fn-engine.lua`** — pure state-machine module. Public API: a constructor returning a stateful object with one input method (advance with an event token + optional payload) that returns the list of action tokens to perform. Pure Lua, no `hs.*` imports — enforced by convention and verified naturally by tests (which run under plain `lua` and would crash on any `hs.*` reference).
- **`hammerspoon/space-fn.lua`** — adapter module. Owns one `hs.eventtap` instance (filtering for `keyDown` and `keyUp` event types). On each event, builds the corresponding engine input, calls the engine, executes the returned action list. Owns the long-hold `hs.timer.doAfter` handle. Exposes a `start()` / `stop()` API and a `setEnabled(bool)` method used by the windows-mode integration. Holds a re-entrancy guard so synthetic events posted via `hs.eventtap.keyStroke` are not re-processed by the same eventtap.
- **`hammerspoon/windows.lua`** (modified) — adds entered/exited hooks that toggle `space-fn`'s enabled state. Bindings file (`hammerspoon/windows-bindings-defaults.lua`) gains arrow-key entries mirroring the existing `i/j/k/l` actions.
- **`hammerspoon/init.lua`** (modified) — adds `require('keyboard.space-fn')` and calls its `start()`.

The three scratchpad files (`super.lua`, `super-new.lua`, `super-backup.lua`) are deleted in the same commit.

### State machine

Three states: `idle`, `pending`, `committed-fn`. One long-hold timer. One buffer of `(keycode, modifiers)` tuples captured during `pending`.

Transitions (event in italics, → action):

- **`idle`** — *space-down* → enter `pending`, start 750ms timer, suppress space. *space-down autorepeat* → ignore (suppress). *any other key event* → pass through unchanged.
- **`pending`** — *mapped key-down* → buffer it, suppress. *unmapped key-down* → abort: cancel timer, emit literal space, emit literal key, return to `idle`. *buffered key-up* → commit: cancel timer, emit all buffered keys remapped, transition to `committed-fn`. *space-up* → roll: cancel timer, emit literal space, emit all buffered keys literally in original order, return to `idle`. *long-hold timer fires* → commit: emit any buffered keys remapped, transition to `committed-fn` (timer firing with empty buffer is fine — engine enters committed-fn silently).
- **`committed-fn`** — *mapped key-down* → emit remapped immediately, stay. *unmapped key-down* → suppress (swallow). *any key-up* → pass through (does not change state). *space-up* → return to `idle`.

Multi-key behaviour falls out of the rules above without special-casing: in `pending`, the first non-space key-up among the buffer commits the entire press to `committed-fn`. From that moment, every key (buffered or new) emits its remap immediately. If `space-up` fires first while multiple keys are buffered, all buffered keys emit literally in original order.

### Tap-roll replay

Approach: full synthetic keystrokes via `hs.eventtap.keyStroke({}, key)` for both space and any buffered keys when rolling. The user's physical keys may still be held; their real key-up events arrive later as stray key-ups, which macOS applications tolerate (see "Further Notes" for the research summary). Hold-to-repeat on rolled-onto keys works naturally because the HID layer continues to send autorepeat key-downs while the physical key is held, and those autorepeats pass through unchanged once we're back in `idle`.

### Modifier propagation

For arrow/delete remaps (`i/j/k/l/h`): emit the bare keycode and let the synthetic event carry whatever physical modifier flags are held at emit time (read from the originating event or via `hs.eventtap.checkKeyboardModifiers()`). This makes `cmd+shift+space+j` compose to `cmd+shift+left`.

For multi-key remaps that already specify their own modifiers (`u → cmd+shift+[`, `o → cmd+shift+]`, `v → ctrl+opt+v`): emit the full prescribed combo via `hs.eventtap.keyStroke(mods, key)`. Any physical modifiers held compose with this in whatever way macOS already does.

### Keymap

Defined as a Lua table at the top of `space-fn.lua` (small enough not to warrant its own file). Initial contents:

```
i → up, j → left, k → down, l → right
h → delete
u → cmd+shift+[ (prev tab), o → cmd+shift+] (next tab)
v → ctrl+opt+v
```

No "training mode."

### Engagement gating

Space-fn engages regardless of which physical modifiers are held at `space-down` (the user actively composes chords like `cmd+shift+space+j`). Modifier composition is handled by propagation, not by gating.

Space-fn is disabled while the windows-layout modal is active. The modal's `entered`/`exited` callbacks call `space-fn.setEnabled(false/true)`. When disabled, the eventtap returns `false` from its callback (pass through) without entering the state machine.

### Long-hold timer

A single `hs.timer.doAfter(0.75, ...)` started on `space-down`. Stored on the adapter's state object. Cancelled on any state-changing event in `pending`. Fires only if no other event interrupts; on fire, commits engine to `committed-fn`. The 750ms value lives as a constant near the top of `space-fn.lua` (e.g., `COMMIT_HOLD_MS = 750`) and is tunable from one place.

### Windows-mode integration

Two changes to `hammerspoon/windows.lua` and `windows-bindings-defaults.lua`:

1. **Disable hook**: `windowLayoutMode.entered` and `.exited` callbacks call `require('keyboard.space-fn').setEnabled(false)` / `setEnabled(true)`. Wired via composition (call existing callback then call space-fn) so the status-message logic is preserved.
2. **Arrow bindings**: `windows-bindings-defaults.lua` gains four new entries mirroring `i/j/k/l`:
   - `{ {}, 'left', 'left' }`
   - `{ {}, 'right', 'right' }`
   - `{ {}, 'up', 'up' }`
   - `{ {}, 'down', 'down' }`

The arrow bindings serve a standalone purpose (one-handed window operations) and also happen to align with what space-fn emits during chord-mode, so chords inside windows-mode would functionally work — though we disable space-fn in windows-mode anyway, to prevent leakage from non-aligned chord keys (`h`/`u`/`o`/etc.).

### Re-entrancy guard

The adapter sets `state.emittingSelf = true` before posting any synthetic event via `hs.eventtap.keyStroke`. The eventtap callback bails (returns `false`) immediately if that flag is set, then clears it after the post completes. Prevents synthetic emissions from re-entering the state machine.

### Logging

`hs.logger.new('space-fn', 'info')` at the top of the adapter. `log.d(...)` calls at every state transition with the from-state, to-state, event, and resulting actions. Off by default at info level. The user can flip to verbose tracing from the Hammerspoon Console via `require('keyboard.space-fn').log.setLogLevel('debug')`.

### Init wiring

`hammerspoon/init.lua` gains `require('keyboard.space-fn').start()` near the end (after the existing `require('keyboard.windows')` so the windows-mode hooks can be attached).

### Test toolchain

- **busted** as the test framework (installed via LuaRocks).
- **LuaRocks** as the package manager — installed via Homebrew (`brew "luarocks"` added to Brewfile).
- **Lua interpreter** for the test runner — `brew "lua"` added to Brewfile (Hammerspoon ships its own Lua, but busted's CLI runs under standalone `lua`).
- **Project-local install tree**: `luarocks --tree=lua_modules install busted` puts everything in `./lua_modules/` (gitignored). No global package pollution.
- **Setup flow**: `script/setup` gains the `luarocks --tree=lua_modules install busted` line after the existing `brew bundle` step. Idempotent (LuaRocks no-ops if already installed).
- **`.busted` config** at the repo root configures the runner to add `./hammerspoon/?.lua` to `package.path` so `require('keyboard.space-fn-engine')` resolves correctly from `spec/`.

### Public commands (Makefile)

A `Makefile` at the repo root with three targets:

- `make install` — delegates to `./script/setup` (the existing entry point).
- `make test` — runs `./lua_modules/bin/busted`.
- `make test-watch` — runs `./lua_modules/bin/busted --watch`.

`make install` is the documented setup command going forward; `script/setup` is the implementation. This gives Lua devs the canonical `make test` entry while preserving the working setup script.

### CLAUDE.md changes

Remove the "no package manager beyond Homebrew" item from "Deliberate non-choices." Add a new section documenting the testing setup (busted, LuaRocks, project-local `lua_modules`, `make test`, where specs live). Update the architecture overview to mention `space-fn-engine.lua` and `space-fn.lua` in place of the three deleted scratchpads, and remove the warning about treating `super*.lua` as scratchpads.

### README changes

The current `README.md` is essentially empty. Fill it with a brief overview (what this is, who it's for) and an "Installation" / "Running tests" section pointing at `make install` and `make test`. Keep it short — this is a personal keyboard config, not a public library.

### Gitignore

Add `lua_modules/` to `.gitignore`.

## Testing Decisions

### What makes a good test for this engine

Tests describe **user-visible behavior**, not internal state-machine shape. Each `it` block is a scenario phrased the way a user would describe it ("space then j released before space emits left-arrow"). The engine's pure interface — events in, actions out — means each test is a small list of events and an expected action list. No mocking, no setup ceremony.

Tests should be readable as documentation. If we ever refactor the state machine internally (e.g., collapse two states into one), behavior tests still pass because they don't peek at internal state.

### Module under test

Only `space-fn-engine.lua`. The adapter (`space-fn.lua`) is glue around `hs.eventtap` and `hs.timer` — its surface is small, its bugs are obvious at runtime, and unit-testing it would require mocking the Hammerspoon runtime, which is more pain than value. The adapter is verified by using the keyboard.

### Scenarios covered

```
describe('space-fn engine')

  describe('tap')
    it('emits a literal space when tapped with no other key')
    it('emits a literal space when space-up arrives before any other key event')

  describe('roll — space-up wins')
    it('"and i" emits literal space then literal i')
    it('multi-key buffer — space-up first emits space + all buffered keys literally in order')

  describe('chord — other-key-up wins')
    it('space + j released-then-space → emits remapped left-arrow')
    it('space + u released-then-space → emits cmd+shift+[ (prev tab)')
    it('multi-key buffer — first non-space release commits whole press to fn-mode')
    it('after commit, subsequent keys in same press remap immediately without buffering')

  describe('long-hold commit')
    it('holding space alone for 750ms commits silently — no space emitted on release')
    it('holding space + buffered key for 750ms commits and emits remapped buffered key')

  describe('pending unmapped abort')
    it('space then unmapped key aborts: emits literal space + literal key, returns to idle')

  describe('post-commit unmapped swallow')
    it('unmapped key after commit emits nothing')

  describe('autorepeat')
    it('space-down autorepeat events while pending are ignored')

  describe('modifier propagation')
    it('arrow remaps emit with currently-held physical modifiers preserved')
```

Approximately 13–15 `it` blocks total.

### Prior art

This repo has no existing tests. There is no prior art *within* the repo. External prior art used as reference: busted's own examples and Neovim plugin testing conventions (specifically the `spec/*_spec.lua` layout and BDD-style `describe`/`it`).

### Running tests

Manual via `make test`. Watch mode available via `make test-watch` for interactive iteration on the engine.

## Out of Scope

- **"Training mode"** — the `a → toggle` switch in `super-backup.lua` that blocked real arrow keys to force home-row use. Driven by the broken implementation; not a behavior we want back.
- **Auto-exit-on-unbound for windows-mode** — discussed, deferred. Every windows-mode binding already calls `bindWithAutomaticExit`, so the "stuck in mode" scenarios are narrow. Worth a separate UX commit later if it ever feels needed; not part of this PRD.
- **Rockspec / publishing to LuaRocks** — this is a personal config, not a public library. We use LuaRocks as a consumer, not a publisher. No `.rockspec` file.
- **Alternative trigger keys** — space is hard-coded. No config file for "use right-cmd instead." Easy to add later (the keymap and trigger keycode become args to the engine constructor), but not now.
- **Per-app keymap variants** — keymap is global. App-specific behavior (e.g., disable in Terminal, different bindings in editors) is out of scope.
- **Linting / formatting** — no luacheck, no stylua. Could add later as `make lint` / `make fmt` once the Makefile exists, but not now.
- **CI** — no GitHub Actions. This is a personal repo running on one machine.
- **Refactoring `status-message.lua`, `windows.lua` internals, or other unrelated cleanups** — touch them only as much as the wiring requires.
- **Generalising the engine to other modifier-keys** — engine is for space specifically. If we ever want a similar pattern on caps-lock or right-shift, that's a future generalisation, not this work.

## Further Notes

### On stray keyUp tolerance

The tap-roll approach (Approach A from the design grill) emits a full synthetic keystroke for the buffered key, after which the user's physical key release arrives as a stray keyUp with no matching keyDown from the system's perspective. Research summary: macOS applications tolerate this. `NSResponder`'s default `keyUp:` is a no-op; text input commits on keyDown via `interpretKeyEvents:`; macOS itself routinely generates orphan keyUp/keyDown asymmetries (Caps Lock only sends keyDown, cmd+arrow has a known AppKit bug where keyUp is dropped). No real-world reports of stray keyUps causing user-visible breakage were found.

### Why no `hs.hotkey.modal` for fn-mode

`hs.hotkey.modal` requires an explicit hotkey to enter — there's no way to enter it from "space was pressed and the engine decided this is fn-mode now." Our trigger logic is fundamentally about *deciding* based on release order, which only an `hs.eventtap` can observe. Hence the eventtap-based design.

### Why not a Spoon

Same reason the existing windows-mode isn't a Spoon: too much ceremony for a personal config of this size. CLAUDE.md already documents this preference. The decision survives this PRD.

### On reload-on-save

The existing `hs.pathwatcher` in `init.lua` will reload Hammerspoon when the new files are saved. No additional wiring required. The `spec/` directory sits outside `hammerspoon/`, so test-file edits do not trigger Hammerspoon reloads.

### On the deleted scratchpads

Their contents survive in git history (`git log --follow hammerspoon/super-backup.lua` etc.). The keymap definitions and any inline comments worth quoting have been incorporated into this PRD and the new code. No reference value is lost by deleting the files from the tree.
