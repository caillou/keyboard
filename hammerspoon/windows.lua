-- Window layout mode. Layout functions are plain locals; the Ctrl+s modal binds
-- keys to direct references to them (the `mappings` table below), so the dispatch
-- is a single uniform call with no `hs.window` namespace pollution. Native
-- placements (e.g. maximize) are wrapped in a closure so every mapping entry has
-- the same `function(win)` shape.
--
-- Hand-rolled rather than a stock window-manager Spoon (ShiftIt,
-- WindowHalfsAndThirds, MiroWindowsManager, ...) on purpose: it supports
-- non-standard layouts (left40, right60, centerWithFullHeight) those Spoons
-- don't, so swapping one in would be a regression. That capability is the bar
-- to clear if you ever reconsider.
--
-- frame() vs fullFrame() is a deliberate per-function choice: frame() excludes
-- the menu bar/dock (used by the half-screen layouts), fullFrame() is the whole
-- display (used by the quarter-screen layouts).

-- Disable animation globally so window moves are instant.
hs.window.animationDuration = 0

-- +-----------------+
-- |        |        |
-- |  HERE  |        |
-- |        |        |
-- +-----------------+
local function left(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w / 2
  f.h = max.h
  win:setFrame(f)
end

-- +-----------------+
-- |        |        |
-- |        |  HERE  |
-- |        |        |
-- +-----------------+
local function right(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x + (max.w / 2)
  f.y = max.y
  f.w = max.w / 2
  f.h = max.h
  win:setFrame(f)
end

-- +-----------------+
-- |      HERE       |
-- +-----------------+
-- |                 |
-- +-----------------+
local function up(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.w = max.w
  f.y = max.y
  f.h = max.h / 2
  win:setFrame(f)
end

-- +-----------------+
-- |                 |
-- +-----------------+
-- |      HERE       |
-- +-----------------+
local function down(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.w = max.w
  f.y = max.y + (max.h / 2)
  f.h = max.h / 2
  win:setFrame(f)
end

-- +-----------------+
-- |  HERE  |        |
-- +--------+        |
-- |                 |
-- +-----------------+
local function upLeft(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:fullFrame()

  f.x = max.x
  f.y = max.y
  f.w = max.w / 2
  f.h = max.h / 2
  win:setFrame(f)
end

-- +-----------------+
-- |                 |
-- +--------+        |
-- |  HERE  |        |
-- +-----------------+
local function downLeft(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:fullFrame()

  f.x = max.x
  f.y = max.y + (max.h / 2)
  f.w = max.w / 2
  f.h = max.h / 2
  win:setFrame(f)
end

-- +-----------------+
-- |                 |
-- |        +--------|
-- |        |  HERE  |
-- +-----------------+
local function downRight(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:fullFrame()

  f.x = max.x + (max.w / 2)
  f.y = max.y + (max.h / 2)
  f.w = max.w / 2
  f.h = max.h / 2

  win:setFrame(f)
end

-- +-----------------+
-- |        |  HERE  |
-- |        +--------|
-- |                 |
-- +-----------------+
local function upRight(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:fullFrame()

  f.x = max.x + (max.w / 2)
  f.y = max.y
  f.w = max.w / 2
  f.h = max.h / 2
  win:setFrame(f)
end

-- +--------------+
-- |  |        |  |
-- |  |  HERE  |  |
-- |  |        |  |
-- +---------------+
local function centerWithFullHeight(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:fullFrame()

  f.x = max.x + (max.w / 5)
  f.w = max.w * 3 / 5
  f.y = max.y
  f.h = max.h
  win:setFrame(f)
end

-- +-----------------+
-- |      |          |
-- | HERE |          |
-- |      |          |
-- +-----------------+
local function left40(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x
  f.y = max.y
  f.w = max.w * 0.4
  f.h = max.h
  win:setFrame(f)
end

-- +-----------------+
-- |      |          |
-- |      |   HERE   |
-- |      |          |
-- +-----------------+
local function right60(win)
  local f = win:frame()
  local screen = win:screen()
  local max = screen:frame()

  f.x = max.x + (max.w * 0.4)
  f.y = max.y
  f.w = max.w * 0.6
  f.h = max.h
  win:setFrame(f)
end

local function nextScreen(win)
  local currentScreen = win:screen()
  local allScreens = hs.screen.allScreens()
  local currentScreenIndex = hs.fnutils.indexOf(allScreens, currentScreen)
  local nextScreenIndex = currentScreenIndex + 1

  if allScreens[nextScreenIndex] then
    win:moveToScreen(allScreens[nextScreenIndex])
  else
    win:moveToScreen(allScreens[1])
  end
end

local windowLayoutMode = hs.hotkey.modal.new({}, "F16")

windowLayoutMode.entered = function()
  windowLayoutMode.statusMessage:show()
  require("keyboard.space-fn").setEnabled(false)
end
windowLayoutMode.exited = function()
  windowLayoutMode.statusMessage:hide()
  require("keyboard.space-fn").setEnabled(true)
end

-- Bind the given key to call the given function and exit WindowLayout mode
function windowLayoutMode.bindWithAutomaticExit(mode, modifiers, key, fn)
  mode:bind(modifiers, key, function()
    mode:exit()
    fn()
  end)
end

local modifiers = { "ctrl" }
local trigger = "s"
local mappings = {
  {
    {},
    "return",
    function(w)
      w:maximize()
    end,
  },
  { {}, "space", centerWithFullHeight },
  { {}, "j", left },
  { {}, "k", down },
  { {}, "i", up },
  { {}, "l", right },
  { {}, "left", left },
  { {}, "down", down },
  { {}, "up", up },
  { {}, "right", right },
  { { "shift" }, "j", left40 },
  { { "shift" }, "l", right60 },
  { {}, "u", upLeft },
  { {}, "o", upRight },
  { {}, "m", downLeft },
  { {}, ".", downRight },
  { {}, "n", nextScreen },
}

local function getModifiersStr(mods)
  local modMap = { shift = "⇧", ctrl = "⌃", alt = "⌥", cmd = "⌘" }
  local retVal = ""

  for _, v in ipairs(mods) do
    retVal = retVal .. modMap[v]
  end

  return retVal
end

local msgStr = getModifiersStr(modifiers)
msgStr = "Window Layout Mode (" .. msgStr .. (string.len(msgStr) > 0 and "+" or "") .. trigger .. ")"

for _, mapping in ipairs(mappings) do
  local mapModifiers, mapTrigger, winFunction = table.unpack(mapping)

  windowLayoutMode:bindWithAutomaticExit(mapModifiers, mapTrigger, function()
    winFunction(hs.window.focusedWindow())
  end)
end

local message = require("keyboard.status-message")
windowLayoutMode.statusMessage = message.new(msgStr)

-- Use modifiers+trigger to toggle WindowLayout Mode
hs.hotkey.bind(modifiers, trigger, function()
  windowLayoutMode:enter()
end)
windowLayoutMode:bind(modifiers, trigger, function()
  windowLayoutMode:exit()
end)
