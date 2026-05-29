local drawing = require("hs.drawing")
local geometry = require("hs.geometry")
local screen = require("hs.screen")
local styledtext = require("hs.styledtext")

local statusmessage = {}
statusmessage.new = function(messageText)
  local buildParts = function(messageText)
    local frame = screen.primaryScreen():frame()

    local styledTextAttributes = {
      font = { name = "Monaco", size = 24 },
      color = { white = 1.0 },
    }

    local styledText = styledtext.new("🔨 " .. messageText, styledTextAttributes)

    local styledTextSize = drawing.getTextDrawingSize(styledText)
    local padX, padY = 20, 8
    local bgW = styledTextSize.w + padX * 2
    local bgH = styledTextSize.h + padY * 2
    local bgX = frame.x + (frame.w - bgW) / 2
    local bgY = frame.y + (frame.h - bgH) / 2

    local background = drawing.rectangle({ x = bgX, y = bgY, w = bgW, h = bgH })
    background:setRoundedRectRadii(10, 10)
    background:setFillColor({ red = 0, green = 0, blue = 0, alpha = 0.8 })

    local textRect = {
      x = bgX + padX,
      y = bgY + padY,
      w = styledTextSize.w,
      h = styledTextSize.h,
    }
    local text = drawing.text(textRect, styledText)

    return background, text
  end

  return {
    _buildParts = buildParts,
    show = function(self)
      self:hide()

      self.background, self.text = self._buildParts(messageText)
      self.background:show()
      self.text:show()
    end,
    hide = function(self)
      if self.background then
        self.background:delete()
        self.background = nil
      end
      if self.text then
        self.text:delete()
        self.text = nil
      end
    end,
    notify = function(self, seconds)
      local seconds = seconds or 1
      self:show()
      hs.timer.delayed
        .new(seconds, function()
          self:hide()
        end)
        :start()
    end,
  }
end

return statusmessage
