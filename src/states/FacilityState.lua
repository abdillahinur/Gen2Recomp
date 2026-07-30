local FacilityPresentation =
  require("src.ui.FacilityPresentation")

local FacilityState = {}
FacilityState.__index = FacilityState

function FacilityState.new(kind, service, options)
  return setmetatable({
    opaque = false,
    presentation =
      FacilityPresentation.new(kind, service, options),
  }, FacilityState)
end

function FacilityState:update(_, input)
  self.presentation:update(input)
end

function FacilityState:draw()
  local model = self.presentation:model()
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0.96, 0.98, 0.94, 1)
  love.graphics.rectangle("fill", 8, 8, 144, 128)
  love.graphics.setColor(0.08, 0.1, 0.12, 1)
  love.graphics.rectangle("line", 8, 8, 144, 128)
  if model.kind == "message" then
    love.graphics.printf(model.text, 18, 54, 124, "center")
    love.graphics.printf("Z: OK", 18, 112, 124, "right")
    return
  end
  love.graphics.printf(model.title, 14, 14, 132, "center")
  if model.subtitle then love.graphics.print(model.subtitle, 16, 28) end
  if #model.options == 0 then
    love.graphics.printf("NOTHING HERE.", 16, 58, 128, "center")
  elseif model.kind == "party" then
    for index, option in ipairs(model.options) do
      local marker = index == model.selected and ">" or " "
      love.graphics.print(
        ("%s%s L%d %d/%d"):format(
          marker, option.name, option.level, option.hp, option.maxHP),
        15, 34 + (index - 1) * 14)
    end
  else
    local first = math.max(1, math.min(
      math.max(1, #model.options - 7), model.selected - 3))
    for index = first, math.min(#model.options, first + 7) do
      local option = model.options[index]
      local name = type(option) == "table" and option.name or option
      local detail = type(option) == "table" and option.detail or ""
      local marker = index == model.selected and ">" or " "
      love.graphics.print(
        marker .. name, 18, 42 + (index - first) * 11)
      love.graphics.printf(
        detail, 96, 42 + (index - first) * 11, 45, "right")
    end
  end
  love.graphics.print("Z: OK  X: BACK", 52, 121)
end

return FacilityState
