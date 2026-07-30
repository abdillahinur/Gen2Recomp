local SemanticTextProvider =
  require("src.ui.SemanticTextProvider")

local PresentationController = {}
PresentationController.__index = PresentationController

local UPPER_KEYBOARD = {
  { "A", "B", "C", "D", "E", "F", "G", "H", "I" },
  { "J", "K", "L", "M", "N", "O", "P", "Q", "R" },
  { "S", "T", "U", "V", "W", "X", "Y", "Z" },
  { "-", "?", "!", "/", ".", "," },
  { "lower", "DEL", "END" },
}
local LOWER_KEYBOARD = {
  { "a", "b", "c", "d", "e", "f", "g", "h", "i" },
  { "j", "k", "l", "m", "n", "o", "p", "q", "r" },
  { "s", "t", "u", "v", "w", "x", "y", "z" },
  { "-", "?", "!", "/", ".", "," },
  { "UPPER", "DEL", "END" },
}

local function pressed(input, action)
  return input and input:wasPressed(action)
end

local function wrap(value, minimum, maximum)
  if value < minimum then return maximum end
  if value > maximum then return minimum end
  return value
end

function PresentationController.new(services, options)
  options = options or {}
  local renderer = options.renderer
  if not renderer and options.font and love then
    local CrystalFontRenderer =
      require("src.render.CrystalFontRenderer")
    renderer = CrystalFontRenderer.new(options.font)
  end
  return setmetatable({
    dialogue = services.dialogue,
    clock = services.clock,
    names = services.names,
    text = options.textProvider or SemanticTextProvider.new(),
    request = nil,
    choiceIndex = 1,
    clockField = 1,
    nameIndex = 1,
    keyboardX = 1,
    keyboardY = 1,
    keyboardCase = "upper",
    textPage = 1,
    clockStage = nil,
    renderer = renderer,
  }, PresentationController)
end

function PresentationController:_active()
  if self.dialogue and self.dialogue.active then
    return self.dialogue.active
  elseif self.clock and self.clock.active then
    return self.clock.active
  elseif self.names and self.names.active then
    return self.names.active
  end
end

function PresentationController:isActive()
  return self:_active() ~= nil
end

function PresentationController:_reset(request)
  if request == self.request then return end
  self.request = request
  self.choiceIndex = 1
  self.clockField = 1
  self.nameIndex = 1
  self.keyboardX = 1
  self.keyboardY = 1
  self.keyboardCase = "upper"
  self.textPage = 1
  self.clockStage = request.stage
end

function PresentationController:_updateDialogue(request, input)
  if request.kind == "text" then
    if pressed(input, "confirm") then
      local pages = self.text.resolvePages
        and self.text:resolvePages(request.id, request.substitutions)
        or { self.text:resolve(request.id, request.substitutions) }
      if self.textPage < #pages then
        self.textPage = self.textPage + 1
      else
        self.dialogue:advance()
      end
    end
    return
  end
  local promptPages = self.text.choicePromptPages
    and self.text:choicePromptPages(request.id)
  if promptPages and self.textPage <= #promptPages then
    if pressed(input, "confirm") then self.textPage = self.textPage + 1 end
    return
  end
  local count = #request.options
  if pressed(input, "up") then
    self.choiceIndex = wrap(self.choiceIndex - 1, 1, count)
  elseif pressed(input, "down") then
    self.choiceIndex = wrap(self.choiceIndex + 1, 1, count)
  elseif pressed(input, "confirm") then
    self.dialogue:choose(request.options[self.choiceIndex].id)
  end
end

function PresentationController:_updateClock(request, input)
  if request.stage ~= self.clockStage then
    self.clockStage = request.stage
    self.choiceIndex = 1
  end
  if request.stage == "woke_up" or request.stage == "what_time"
      or request.stage == "minute_intro"
      or request.stage == "response" then
    if pressed(input, "confirm") then self.clock:advance() end
  elseif request.stage == "hour_confirm"
      or request.stage == "minute_confirm" then
    if pressed(input, "up") or pressed(input, "down") then
      self.choiceIndex = wrap(self.choiceIndex
        + (pressed(input, "down") and 1 or -1), 1, 2)
    elseif pressed(input, "confirm") then
      self.clock:chooseConfirmation(self.choiceIndex == 1)
    elseif pressed(input, "cancel") then
      self.clock:chooseConfirmation(false)
    end
  elseif pressed(input, "up") or pressed(input, "down") then
    local amount = pressed(input, "up") and 1 or -1
    local hour, minute = request.hour, request.minute
    if request.stage == "hour_select" then
      hour = wrap(hour + amount, 0, 23)
    else
      minute = wrap(minute + amount, 0, 59)
    end
    self.clock:setTime(hour, minute)
  elseif pressed(input, "confirm") then
    self.clock:confirmField()
  end
end

function PresentationController:_nameChoices(request, input)
  local count = #request.presets + 1
  if pressed(input, "up") then
    self.nameIndex = wrap(self.nameIndex - 1, 1, count)
  elseif pressed(input, "down") then
    self.nameIndex = wrap(self.nameIndex + 1, 1, count)
  elseif pressed(input, "confirm") then
    if self.nameIndex == 1 then
      self.names:beginCustom()
      self.request = nil
    else
      self.names:choosePreset(request.presets[self.nameIndex - 1].id)
    end
  end
end

function PresentationController:_customName(request, input)
  local keyboard = self.keyboardCase == "upper"
    and UPPER_KEYBOARD or LOWER_KEYBOARD
  local row = keyboard[self.keyboardY]
  if pressed(input, "left") then
    self.keyboardX = wrap(self.keyboardX - 1, 1, #row)
  elseif pressed(input, "right") then
    self.keyboardX = wrap(self.keyboardX + 1, 1, #row)
  elseif pressed(input, "up") then
    self.keyboardY = wrap(self.keyboardY - 1, 1, #keyboard)
    self.keyboardX = math.min(self.keyboardX, #keyboard[self.keyboardY])
  elseif pressed(input, "down") then
    self.keyboardY = wrap(self.keyboardY + 1, 1, #keyboard)
    self.keyboardX = math.min(self.keyboardX, #keyboard[self.keyboardY])
  elseif pressed(input, "cancel") then
    self.names:backToChoices()
    self.request = nil
  elseif pressed(input, "confirm") then
    local key = keyboard[self.keyboardY][self.keyboardX]
    if key == "DEL" then
      self.names:setCustom(request.custom:sub(1, -2))
    elseif key == "END" then
      if request.custom ~= "" then self.names:submitCustom() end
    elseif key == "lower" or key == "UPPER" then
      self.keyboardCase = key == "lower" and "lower" or "upper"
    elseif #request.custom < self.names.maximumLength then
      self.names:setCustom(request.custom .. key)
    end
  end
end

function PresentationController:update(input)
  local request = self:_active()
  if not request then
    self.request = nil
    return false
  end
  self:_reset(request)
  if self.dialogue and request == self.dialogue.active then
    self:_updateDialogue(request, input)
  elseif self.clock and request == self.clock.active then
    self:_updateClock(request, input)
  elseif request.stage == "custom" then
    self:_customName(request, input)
  else
    self:_nameChoices(request, input)
  end
  return true
end

function PresentationController:model()
  local request = self:_active()
  if not request then return nil end
  self:_reset(request)
  if self.dialogue and request == self.dialogue.active then
    if request.kind == "text" then
      local pages = self.text.resolvePages
        and self.text:resolvePages(request.id, request.substitutions)
        or { self.text:resolve(request.id, request.substitutions) }
      return {
        kind = "text",
        text = pages[self.textPage],
        page = self.textPage,
        pageCount = #pages,
        footer = self.textPage < #pages
          and ("Z: NEXT  %d/%d"):format(self.textPage, #pages)
          or "Z / ENTER: CLOSE",
      }
    end
    local promptPages = self.text.choicePromptPages
      and self.text:choicePromptPages(request.id)
    if promptPages and self.textPage <= #promptPages then
      return {
        kind = "text",
        text = promptPages[self.textPage],
        page = self.textPage,
        pageCount = #promptPages,
        footer = ("Z: NEXT  %d/%d"):format(
          self.textPage, #promptPages),
      }
    end
    local options = {}
    for index, option in ipairs(request.options) do
      options[index] = self.text:option(option)
    end
    return {
      kind = "choice",
      id = request.id,
      prompt = promptPages and promptPages[#promptPages],
      title = self.text.choiceTitle
        and self.text:choiceTitle(request.id)
        or self.text:resolve(request.id),
      options = options,
      selected = self.choiceIndex,
    }
  elseif self.clock and request == self.clock.active then
    local stage = request.stage
    local textByStage = {
      woke_up = "crystal.text.introduction.clock_woke_up",
      what_time = "crystal.text.introduction.clock_what_time",
      minute_intro = "crystal.text.introduction.clock_minutes",
    }
    local text
    if textByStage[stage] then
      text = self.text:resolve(textByStage[stage])
    elseif stage == "hour_confirm" then
      text = self.text:resolve(
        "crystal.text.introduction.clock_what_hours")
        .. "\n" .. request.hour .. " o'clock"
        .. self.text:resolve(
          "crystal.text.introduction.clock_hours_question")
    elseif stage == "minute_confirm" then
      text = self.text:resolve("crystal.text.introduction.clock_whoa")
        .. "\n" .. ("%02d min."):format(request.minute)
        .. self.text:resolve(
          "crystal.text.introduction.clock_minutes_question")
    elseif stage == "response" then
      local id = request.hour < 10
        and "crystal.text.introduction.clock_morning"
        or request.hour < 18
          and "crystal.text.introduction.clock_day"
          or "crystal.text.introduction.clock_night"
      text = ("%d:%02d\n"):format(request.hour, request.minute)
        .. self.text:resolve(id)
    end
    return {
      kind = "clock",
      stage = stage,
      text = text,
      hour = request.hour,
      minute = request.minute,
      selected = self.choiceIndex,
    }
  elseif request.stage == "custom" then
    return {
      kind = "name_keyboard",
      title = "YOUR NAME",
      value = request.custom,
      keyboard = self.keyboardCase == "upper"
        and UPPER_KEYBOARD or LOWER_KEYBOARD,
      selectedX = self.keyboardX,
      selectedY = self.keyboardY,
      footer = "Z: TYPE   X: BACK",
    }
  end
  local options = {}
  options[1] = "NEW NAME"
  for index, preset in ipairs(request.presets) do
    options[index + 1] = preset.value
  end
  return {
    kind = "name_choice",
    title = "CHOOSE YOUR NAME",
    options = options,
    selected = self.nameIndex,
  }
end

local function panel(x, y, width, height)
  love.graphics.setColor(0.96, 0.98, 1, 1)
  love.graphics.rectangle("fill", x, y, width, height)
  love.graphics.setColor(0.08, 0.12, 0.2, 1)
  love.graphics.rectangle("line", x, y, width, height)
  love.graphics.rectangle("line", x + 2, y + 2, width - 4, height - 4)
end

local function drawOptions(model, x, y)
  for index, option in ipairs(model.options) do
    local marker = index == model.selected and ">" or " "
    love.graphics.print(marker .. " " .. option, x, y + (index - 1) * 10)
  end
end

function PresentationController:draw()
  local model = self:model()
  if not model then return end
  if self.renderer then
    local renderer = self.renderer
    if model.kind == "text" then
      renderer:drawDialogue(model.text, true)
    elseif model.kind == "choice" then
      if model.prompt then renderer:drawDialogue(model.prompt, false) end
      local x, y, width, height = 72, 48, 80, 48
      if model.id == "crystal.choice.player_gender" then
        x, y, width, height = 48, 32, 56, 48
      end
      renderer:drawBox(x, y, width, height)
      for index, option in ipairs(model.options) do
        renderer:drawText(
          (index == model.selected and ">" or " ") .. option,
          x + 8,
          y + 8 + (index - 1) * 16
        )
      end
    elseif model.kind == "clock" then
      if model.text then renderer:drawDialogue(model.text, true) end
      if model.stage == "hour_select"
          or model.stage == "minute_select" then
        local value = model.stage == "hour_select"
          and ("%02d o'clock"):format(model.hour)
          or ("%02d min."):format(model.minute)
        renderer:drawBox(32, 32, 96, 40)
        renderer:drawText(value, 48, 48)
      elseif model.stage == "hour_confirm"
          or model.stage == "minute_confirm" then
        renderer:drawBox(96, 40, 56, 48)
        renderer:drawText(
          (model.selected == 1 and ">" or " ") .. "YES",
          104, 48)
        renderer:drawText(
          (model.selected == 2 and ">" or " ") .. "NO",
          104, 64)
      end
    elseif model.kind == "name_choice" then
      renderer:drawBox(64, 16, 88, 112)
      for index, option in ipairs(model.options) do
        renderer:drawText(
          (index == model.selected and ">" or " ") .. option,
          72,
          24 + (index - 1) * 16
        )
      end
    else
      renderer:drawBox(0, 0, 160, 144)
      renderer:drawText("YOUR NAME", 8, 8)
      renderer:drawText(model.value or "", 88, 8)
      for rowIndex, row in ipairs(model.keyboard) do
        for columnIndex, key in ipairs(row) do
          local marker = rowIndex == model.selectedY
            and columnIndex == model.selectedX and ">" or " "
          renderer:drawText(
            marker .. key,
            4 + (columnIndex - 1) * 22,
            36 + (rowIndex - 1) * 20,
            { spacing = 7 }
          )
        end
      end
    end
    return
  end
  love.graphics.setFont(love.graphics.getFont())
  if model.kind == "text" then
    panel(3, 96, 154, 45)
    love.graphics.printf(model.text, 9, 102, 142, "left")
    love.graphics.print(model.footer, 67, 131)
  elseif model.kind == "choice" or model.kind == "name_choice" then
    panel(18, 18, 124, 108)
    love.graphics.printf(model.title, 24, 25, 112, "center")
    drawOptions(model, 31, 46)
  elseif model.kind == "clock" then
    panel(18, 34, 124, 72)
    love.graphics.printf(model.title, 24, 41, 112, "center")
    local hour = ("%02d"):format(model.hour)
    local minute = ("%02d"):format(model.minute)
    local value = (model.selected == 1 and ">" or " ")
      .. hour .. " : "
      .. (model.selected == 2 and ">" or " ") .. minute
    love.graphics.printf(value, 24, 63, 112, "center")
    love.graphics.printf(model.footer, 24, 88, 112, "center")
  else
    panel(4, 8, 152, 132)
    love.graphics.printf(
      model.title .. ": " .. model.value, 10, 14, 140, "center")
    for rowIndex, row in ipairs(model.keyboard) do
      for columnIndex, key in ipairs(row) do
        local selected = rowIndex == model.selectedY
          and columnIndex == model.selectedX
        local label = selected and "[" .. key .. "]" or key
        love.graphics.printf(
          label,
          7 + (columnIndex - 1) * 21,
          39 + (rowIndex - 1) * 17,
          20,
          "center"
        )
      end
    end
    love.graphics.printf(model.footer, 10, 121, 140, "center")
  end
end

return PresentationController
