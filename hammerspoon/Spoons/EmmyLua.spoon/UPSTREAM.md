# EmmyLua.spoon — vendoring provenance

This is a vendored, unmodified copy of EmmyLua.spoon from the official
Hammerspoon Spoons repository. It is a build-time code generator: when
Hammerspoon loads it, it introspects the installed `hs` API and writes EmmyLua
annotation stubs under `annotations/` (gitignored), which LuaLS reads for
`hs.*` autocomplete.

The source files (`init.lua`, `docs.json`) are kept unmodified. Refresh with
`make update-emmylua` (see `script/update-emmylua`).

## Source

- Distributable zip: https://github.com/Hammerspoon/Spoons/raw/master/Spoons/EmmyLua.spoon.zip
- Source tree: https://github.com/Hammerspoon/Spoons/tree/master/Source/EmmyLua.spoon
- Upstream repo: https://github.com/Hammerspoon/Spoons
- License: MIT (retained in `init.lua`)

## Retrieved

- Date: 2026-05-30
- Hammerspoon/Spoons master commit: 5c20bcecc380acff5f0f5df7a718c5679aaaf62a
- Last commit touching the EmmyLua source: 209078964afee95448b5d6629f4ba3d04d0b39b9
