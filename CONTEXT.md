# Keyboard

A personal macOS keyboard customization built on Hammerspoon (Lua, no build step). Two subsystems: a window-layout modal and a space-as-modifier ("space-fn") layer.

## Language

### space-fn

**Engine**:
The pure state machine that decides space-fn behavior. Abstract event tokens in, abstract action tokens out, no `hs.*` dependencies. The only unit-tested code. Lives in `space-fn-engine.lua`.
_Avoid_: state machine (when you mean the file), core

**Adapter**:
The thin Hammerspoon glue that owns the `hs.eventtap` and timer, translates real key events into Engine inputs, and dispatches Engine outputs back into `hs` calls. Kept as thin as possible — logic worth testing moves into the Engine. Lives in `space-fn.lua`.
_Avoid_: wrapper, glue (informally fine, but "Adapter" is the term)

**Event token**:
An abstract input the Adapter feeds the Engine, naming a physical occurrence without any `hs` detail (`space-down`, `space-down-autorepeat`, `space-up`, `key-down`, `key-up`, `timer-fire`).
_Avoid_: input, message

**Action token**:
An abstract output the Engine returns for the Adapter to perform (`emit-space`, `emit-key`, `emit-remap`, `suppress`, `passthrough`, `start-timer`, `cancel-timer`).
_Avoid_: command, output, effect

**Roll**:
Releasing space *after* pressing the next key while typing fast (e.g. "and i"). The Engine emits a literal space then the literal key — it does not treat space as a modifier. The case all three earlier attempts got wrong.
_Avoid_: rollover, fat-finger

**Chord**:
Holding space as a modifier together with a mapped key (e.g. space+j = left-arrow). Distinguished from a Roll by release order: the chord key releases before space.
_Avoid_: combo, shortcut
