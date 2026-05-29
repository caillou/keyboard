## Toward a more useful keyboard

Personal macOS keyboard customization, built on [Hammerspoon](https://www.hammerspoon.org/). Two features:

- **Window layout mode**: a `Ctrl+s` modal that moves and resizes the focused window with single keys (`h/j/k/l`, `i/o/m/.`, and friends).
- **Space-fn**: tap space to type a space, hold space plus another key to use space as a modifier (`space+j` for left-arrow, `space+h` for delete, `space+u`/`space+o` for prev/next tab, and so on).

This is a personal config, not a published library. It's checked in so I can clone it onto a new machine and run one command.

## Installation

```
make install
```

That runs `script/setup`, which installs dependencies via Homebrew, symlinks `hammerspoon/` into `~/.hammerspoon/keyboard`, wires `require('keyboard')` into `~/.hammerspoon/init.lua`, installs the Lua test toolchain into `lua_modules/`, and (re)launches Hammerspoon. Idempotent, so it's safe to re-run after pulling.

## Running tests

```
make test
```

Runs the busted spec suite against the space-fn state machine. For interactive iteration:

```
make test-watch
```

See `CLAUDE.md` for the architecture overview and the rationale behind the test setup.
