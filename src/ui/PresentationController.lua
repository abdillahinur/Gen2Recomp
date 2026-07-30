local SemanticTextProvider =
  require("src.ui.SemanticTextProvider")

local PresentationController = {}
PresentationController.__index = PresentationController

local KEYBOARD = {
  { "A", "B", "C", "D", "E", "F", "G" },
  { "H", "I", "J", "K", "L", "M", "N" },
  { "O", "P", "Q", "R", "S", "T", "U" },
  { "V", "W", "X", "Y", "Z", "DEL", "END" },
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
end

function PresentationController:_updateDialogue(request, input)
  if request.kind == "text" then
    if pressed(input, "confirm") then self.dialogue:advance() end
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
  if pressed(input, "left") then
    self.clockField = wrap(self.clockField - 1, 1, 2)
  elseif pressed(input, "right") then
    self.clockField = wrap(self.clockField + 1, 1, 2)
  elseif pressed(input, "up") or pressed(input, "down") then
    local amount = pressed(input, "up") and 1 or -1
    local hour, minute = request.hour, request.minute
    if self.clockField == 1 then
      hour = wrap(hour + amount, 0, 23)
    else
      minute = wrap(minute + amount, 0, 59)
    end
    self.clock:setTime(hour, minute)
  elseif pressed(input, "confirm") then
    self.clock:confirm()
  end
end

function PresentationController:_nameChoices(request, input)
  local count = #request.presets + 1
  if pressed(input, "up") then
    self.nameIndex = wrap(self.nameIndex - 1, 1, count)
  elseif pressed(input, "down") then
    self.nameIndex = wrap(self.nameIndex + 1, 1, count)
  elseif pressed(input, "confirm") then
    local preset = request.presets[self.nameIndex]
    if preset then
      self.names:choosePreset(preset.id)
    else
      self.names:beginCustom()
      self.request = nil
    end
  end
end

function PresentationController:_customName(request, input)
  if pressed(input, "left") then
    self.keyboardX = wrap(self.keyboardX - 1, 1, 7)
  elseif pressed(input, "right") then
    self.keyboardX = wrap(self.keyboardX + 1, 1, 7)
  elseif pressed(input, "up") then
    self.keyboardY = wrap(self.keyboardY - 1, 1, #KEYBOARD)
  elseif pressed(input, "down") then
    self.keyboardY = wrap(self.keyboardY + 1, 1, #KEYBOARD)
  elseif pressed(input, "cancel") then
    self.names:backToChoices()
    self.request = nil
  elseif pressed(input, "confirm") then
    local key = KEYBOARD[self.keyboardY][self.keyboardX]
    if key == "DEL" then
      self.names:setCustom(request.custom:sub(1, -2))
    elseif key == "END" then
      if request.custom ~= "" then self.names:submitCustom() end
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
      return {
        kind = "text",
        text = self.text:resolve(request.id, request.substitutions),
        footer = "Z / ENTER: NEXT",
      }
    end
    local options = {}
    for index, option in ipairs(request.options) do
      options[index] = self.text:option(option)
    end
    return {
      kind = "choice",
      title = self.text:resolve(request.id),
      options = options,
      selected = self.choiceIndex,
    }
  elseif self.clock and request == self.clock.active then
    return {
      kind = "clock",
      title = "SET THE CLOCK",
      hour = request.hour,
      minute = request.minute,
      selected = self.clockField,
      footer = "ARROWS: CHANGE   Z: CONFIRM",
    }
  elseif request.stage == "custom" then
    return {
      kind = "name_keyboard",
      title = "YOUR NAME",
      value = request.custom,
      keyboard = KEYBOARD,
      selectedX = self.keyboardX,
      selectedY = self.keyboardY,
      footer = "Z: TYPE   X: BACK",
    }
  end
  local options = {}
  for index, preset in ipairs(request.presets) do
    options[index] = preset.value
  end
  options[#options + 1] = "CUSTOM"
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
