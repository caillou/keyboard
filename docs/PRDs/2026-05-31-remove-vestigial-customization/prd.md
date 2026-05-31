# Remove vestigial customization machinery and dead code

## Problem Statement

This repo descends from an upstream Hammerspoon config (the mxstbr lineage) that
shipped a "gitignored defaults + user override" customization pattern. In this
personal fork that pattern was **never used**: the user override file
(`windows-bindings.lua`) has not existed at any point in git history since the
defaults file was introduced in December 2017, and the README explicitly states
this is "a personal config, not a published library."

The result is indirection that pretends to be configurable but isn't:

- `windows.lua` loads bindings through a `pcall(require, "keyboard.windows-bindings")`
  that always fails, then falls back to `windows-bindings-defaults.lua`. The
  "defaults" file is therefore the only file that has ever run — the `-defaults`
  suffix names a partner file that does not exist.
- `.gitignore` reserves slots for three files/dirs that this fork never created:
  the windows override, `hyper-apps.lua` (hyper mode was never ported here), and
  `karabiner/automatic_backups` (there is no `karabiner/` directory).
- A `showHelp` flag is hard-coded `false`, so a whole per-key help-text
  rendering loop in `windows.lua` is dead.

Alongside the customization machinery, the same upstream lineage left several
zero-caller exports: `keyUpDown` and `enableHotkeyForWindowsMatchingFilter` in
`init.lua`, `M.log` and `M.stop()` in `space-fn.lua`, and `:notify()` in
`status-message.lua`. Each is carried (and in the luacheck case, explicitly
allow-listed) for a customization/extensibility story this fork does not have.

A reader — human or AI — has to reverse-engineer that none of this is load-bearing
before touching the window subsystem. The indirection actively misleads.

## Solution

Collapse the window bindings down to a single, hard-coded source of truth inlined
into `windows.lua`, and remove the dead exports and stale ignore-rules that the
customization lineage left behind. After this change, "how the window layout mode
is configured" is answered by reading one table in one file, with no override
mechanism to discover and no dead branches to mentally execute.

Behavior at runtime is unchanged: the same keys map to the same window layouts,
the same modal overlay shows the same title, and the space-fn layer behaves
identically. This is a clarity and maintenance change, not a feature change.

## User Stories

1. As a developer returning to this repo, I want the window bindings to live in
   one obvious place, so that I don't have to trace a `pcall`/fallback chain to
   learn which file actually runs.
2. As a developer, I want the misleading `-defaults` suffix gone, so that a
   filename never implies a partner file that doesn't exist.
3. As a developer, I want `windows.lua` to contain no dead `if showHelp` branch,
   so that every line I read is a line that executes.
4. As a developer, I want the window-key dispatch to be a single expression, so
   that I'm not led to believe there are two resolution paths when only one fires.
5. As a developer, I want `init.lua` free of helper globals that nothing calls,
   so that the module's surface reflects what the config actually uses.
6. As a developer, I want `.luacheckrc` to stop allow-listing globals that no
   longer exist, so that the lint config documents only real, intentional globals.
7. As a developer, I want `space-fn.lua` to export only what is used, so that the
   Adapter's public surface matches the Adapter's actual role.
8. As a developer, I want `status-message.lua` to expose only `show`/`hide`, so
   that the status overlay's API matches its single caller.
9. As a developer, I want `.gitignore` to reference only files this repo can
   actually produce, so that stale entries don't imply features that were never
   ported.
10. As a developer, I want `CLAUDE.md` to stop pointing at a
    `windows-bindings*.lua` file pair that no longer exists, so that the router
    stays accurate.
11. As a user of the keyboard config, I want the window layout mode to behave
    exactly as before, so that this cleanup costs me nothing at the keyboard.
12. As a user, I want the space-fn layer to behave exactly as before, so that the
    space-as-modifier behavior is untouched by the cleanup.
13. As a maintainer, I want the existing Engine spec suite to still run and pass
    after the change, so that I have confidence the space-fn behavior was not
    disturbed.
14. As a maintainer, I want `make lint` and `make fmt-check` to stay green, so
    that the lefthook pre-commit gate continues to pass.
15. As a maintainer, I want a single live verification step documented, so that I
    can confirm the one behavior the test suite structurally cannot cover (the
    window-key dispatch resolving through `hs.window`).
16. As a developer, I want the window-layout functions defined as locals rather
    than injected onto `hs.window`, so that the LSP is warning-free and the
    dispatch is a single uniform call with no namespace pollution.

## Implementation Decisions

### Inline the window bindings into `windows.lua`

- Delete `hammerspoon/windows-bindings-defaults.lua`.
- Remove the `pcall(require, "keyboard.windows-bindings")` try/fallback block.
  Replace it with the binding configuration declared directly in `windows.lua`.
- Hard-code `modifiers = { "ctrl" }` and `trigger = "s"` as plain locals.
- Inline the `mappings` array unchanged (same keys → same window functions,
  including `return → maximize`, `space → centerWithFullHeight`, the `h/j/k/l`
  and arrow rows, the `shift` rows for `left40`/`right60`, the quarter rows, and
  `n → nextScreen`).

### Collapse to one source of truth (full collapse, computed title)

- Drop the `showHelp` flag and the entire `if showHelp == true then ... end`
  help-text rendering loop, including the now-unused `hotKeyStr` branch.
- **Keep** `getModifiersStr` and use it to build the modal title from the
  hard-coded `modifiers`/`trigger` locals. Rationale: the two `hs.hotkey` binds
  (mode enter/exit) reference the same `modifiers`/`trigger` locals, so keeping
  the title computed from them preserves a single source of truth — changing the
  trigger key is still a one-line edit. (Rejected: hard-coding the literal title
  string, which would duplicate the `⌃` glyph and the trigger across three sites.)

### Collapse the window-key dispatch to a single expression

- Replace the two-branch dispatch:

  ```lua
  local fw = hs.window.focusedWindow()
  if fw[winFunction] then
    fw[winFunction](fw)
  else
    hs.window[winFunction](fw)
  end
  ```

  with a single call: `hs.window[winFunction](hs.window.focusedWindow())`.

- Rationale: every mapped function resolves off the `hs.window` table — the
  custom layout functions are assigned there directly (`hs.window.left`,
  `hs.window.upRight`, …) and native `maximize` resolves through it. The `else`
  branch never fired.
- **Risk, called out explicitly:** this relies on `hs.window`-table resolution
  for both custom and native functions and cannot be proven without a live
  Hammerspoon. It is the one change in this PRD that the spec suite cannot cover,
  and it is the subject of the live verification step (see Testing Decisions).

### Remove dead exports and their lint allowances

- `init.lua`: remove the `keyUpDown` global and the
  `enableHotkeyForWindowsMatchingFilter` global (both zero-caller).
- `.luacheckrc`: remove `keyUpDown` and `enableHotkeyForWindowsMatchingFilter`
  from the `globals` list, and update the surrounding comment so it no longer
  describes them. Keep `configWatcher` and `keyboardWatcher` (the pathwatchers
  must stay global or they get garbage-collected).
- `space-fn.lua`: remove `M.log = log` (the Adapter's own local `log` stays for
  internal use) and remove the unused `M.stop()` function. `M.start` and
  `M.setEnabled` remain — they are the surface `init.lua` and `windows.lua` use.
- `status-message.lua`: remove the `notify` method. `show` and `hide` remain —
  they are the only methods `windows.lua` calls.

### Clean up stale `.gitignore` entries

Remove three entries that reference files/dirs this fork never produces:

- `hammerspoon/windows-bindings.lua` (the override file being designed out).
- `hammerspoon/hyper-apps.lua` (hyper mode was never ported into this fork).
- `karabiner/automatic_backups` (no `karabiner/` directory exists; the
  karabiner-elements cask is commented out in the `Brewfile`).

### Update documentation

- `CLAUDE.md`: update the Window-layout-mode subsystem line that currently reads
  `windows.lua` (+ `windows-bindings*.lua`) so it no longer references the
  deleted bindings file pair.
- README needs no change — it never documented the override pattern.

### No ADR

Considered and declined. The README already establishes this is a personal
config, not a published library, so forkability is not a goal that the removed
pattern was serving. The inline table plus the `.gitignore`/`CLAUDE.md` cleanups
remove every dangling reference, so a future reader has nothing left to be
surprised by.

### No CONTEXT.md changes

No new domain vocabulary is introduced or changed; the existing glossary
(Engine, Adapter, Roll, Chord, Event/Action token) is untouched. These are all
implementation details, which the glossary deliberately excludes.

## Testing Decisions

- **What makes a good test here:** external behavior only. The space-fn behavior
  is owned by the pure Engine and is already covered by the busted spec suite per
  `docs/adr/0001` ("push decisions into the Engine rather than mock `hs`").
- **No new tests are written.** Every change in this PRD is removal of dead code,
  inlining of an existing data table, or collapsing a branch that does not alter
  observable behavior. None of it adds Engine logic, which is the only thing the
  unit-test boundary covers. Adding a `windows.lua` smoke test was considered and
  rejected: it would require mocking `hs.window`, which ADR 0001 explicitly steers
  away from.
- **The existing Engine spec suite must still run and pass.** `make test` is a
  required gate for this change — it confirms the space-fn layer (whose Adapter
  loses `M.log`/`M.stop`) is undisturbed. Prior art: the entire
  `spec/space-fn-engine_spec.lua` suite is the model; this PRD adds nothing to it
  but must not break it.
- **`make lint` and `make fmt-check` must stay green**, since both are enforced
  by the lefthook pre-commit hook (`docs/adr/0002`). The `.luacheckrc` edit is
  what keeps lint green after the two globals are removed.
- **One live verification step is mandatory and cannot be automated:** after the
  change, reload Hammerspoon (`hs -c "hs.reload()"`) and confirm the window layout
  mode still works end to end — specifically `Ctrl+s` then `return` (native
  `maximize`, the function most likely to expose a wrong dispatch assumption) and
  `Ctrl+s` then a custom layout key such as `j`/`l` (a custom `hs.window.*`
  function). This is the only check that exercises the collapsed single-line
  dispatch.

## Out of Scope

- The `inputrc` file and the commented-out `inputrc` install line in
  `script/setup`: deliberately kept. The user chose to retain them; they are not
  part of this pass.
- The `EmmyLua.spoon` under `hammerspoon/Spoons/`: vendored upstream dev tooling,
  loaded via `pcall` by design, not vestigial.
- The commented-out `karabiner-elements` cask in the `Brewfile`: left as-is; only
  the stale `.gitignore` path is removed, not the Brewfile comment.
- Any change to space-fn behavior, the Engine, or the window layout functions
  themselves (`left`, `right`, `upLeft`, …). Their geometry is untouched.
- Adding test infrastructure for `windows.lua` or `status-message.lua`.

## Further Notes

- The headline reframe driving this PRD: `windows-bindings-defaults.lua` is **not**
  the vestigial part — it is the file actually doing the work. The vestigial part
  is the override pattern wrapped around it (the `pcall`, the gitignored partner
  file, the "copy this file" comment). The cleanup deletes the `-defaults` file
  only because its contents move inline and the override partner it was named
  against is being removed.
- Sub-agent research established the key facts behind these decisions: the
  `windows-bindings.lua` override has never existed in git history (back to the
  Dec 2017 introduction of the defaults file); the dead exports
  (`keyUpDown`, `enableHotkeyForWindowsMatchingFilter`, `M.log`, `M.stop`,
  `:notify`) have zero callers across `hammerspoon/` and `spec/`; and the
  `hyper-apps.lua` / `karabiner` ignore entries point at files/dirs absent from
  this fork.
- The change touches six files (`windows.lua`, `init.lua`, `.luacheckrc`,
  `space-fn.lua`, `status-message.lua`, `.gitignore`, plus `CLAUDE.md`) and
  deletes one (`windows-bindings-defaults.lua`). It is surgical and
  behavior-preserving by intent.

## Errata

The Implementation Decision **"Collapse the window-key dispatch to a single
expression"** was **reversed** in implementation. Its premise — that "every
mapped function resolves off the `hs.window` table" and "the `else` branch never
fired" — is false. Live testing proved the `else` branch is not dead: it is the
path for every custom layout key. The root cause is two different tables.
`hs.window[winFunction]` (module-table indexing) resolves the custom layout
functions (assigned as `function hs.window.<name>`) but **not** native
`maximize`; `fw[winFunction]` (instance indexing) resolves native methods like
`maximize` but **not** the custom layouts, because a window object's metatable
`__index` is the internal C methods table, not the `hs.window` module table. Each
single-expression form was tried and broke exactly half the keys.

Consequently **User Story 4** ("I want the window-key dispatch to be a single
expression") is **not achievable and is withdrawn**. The dispatch remains the
original two-branch form, now carrying a comment documenting why it must not be
re-collapsed.

The PRD's own **"Risk, called out explicitly"** subsection correctly anticipated
that this was the one change the spec suite could not cover and that it could
only be settled by live Hammerspoon verification. That risk materialized: live
verification failed for the collapsed form, and the change was reverted.

All other decisions in this PRD shipped as written and are behavior-preserving.

## Follow-up: localize layout functions (resolves the dispatch errata)

A deeper review — triggered by a LuaLS `inject-field` diagnostic — found that the
Errata above treated a symptom, not the cause. The two-branch dispatch is not an
irreducible fact of the design; it is forced by an upstream choice the Errata took
as given: the ~12 window-layout functions are **monkey-patched onto the
`hs.window` module table** (`function hs.window.left(win) ... end`, …). That one
choice produces three distinct symptoms:

1. LuaLS emits an `inject-field` warning on every such definition ("Fields cannot
   be injected into the reference of `hs.window` … use `---@class`").
2. The dispatch asymmetry the Errata documented: custom fns live on the
   `hs.window` **module** table; native methods like `maximize` live on the window
   object's **metatable**. No single-table lookup resolves both — hence the
   restored two branches.
3. String-keyed dispatch (mappings store `"down"` etc. as strings) forces a
   runtime table lookup that then has to guess which table holds the function.

**Decision — localize the layout functions and fix the data model first.** Define
the layout functions as plain `local function`s (geometry bodies verbatim), have
the `mappings` array hold **direct function references** instead of name strings,
wrap native `maximize` uniformly as `function(w) w:maximize() end`, and reduce the
dispatch to a single branch-free call:

```lua
mapping.fn(hs.window.focusedWindow())
```

This removes the monkey-patch (all ~12 LuaLS warnings vanish), the two-branch
dispatch, the string lookup, and the `hs.window` namespace pollution in one move.

This **revives the intent of User Story 4** — a single-expression dispatch — by
fixing the data model rather than rewriting the dispatch line in isolation. The
PRD was right about the goal and wrong about the mechanism: collapsing the
dispatch is only safe once the functions no longer straddle two tables. US4 is
therefore **no longer "withdrawn" but "achieved via refactor."**

Companion cleanups in scope:

- **`.luacheckrc`:** the carve-out `files['hammerspoon/windows.lua'] = { globals =
  { 'hs.window' } }` existed to allow the monkey-patches. After localizing, that
  purpose is gone, but the legitimate real-API write `hs.window.animationDuration
  = 0` at the top of `windows.lua` still needs an allowance. Retarget the carve-out
  and its comment to cover only that write — do **not** blanket-delete it.
- **Stale header comment:** the `windows.lua` header claims a "LuaLS carve-out" in
  `.vscode/settings.json` that does not exist. Correct or remove that claim.
- **Preserve all real `hs.window` API usage verbatim** (`animationDuration`,
  `focusedWindow`, native methods).

Behavior parity is required (all 17 keys → identical geometry) and the dispatch
change is again gated on live Hammerspoon verification, since it is the one
behavior the spec suite structurally cannot cover.

Blast-radius analysis found **zero** external callers of the custom layout fns —
every reference lives inside `windows.lua`. (The only theoretical residual risk is
the user's own ad-hoc `~/.hammerspoon` scripts outside this repo.)

Tracked as a new issue file:
`issues/02. localize window layout functions and collapse dispatch.md`.
