local FieldMenuPresentation =
  require("src.ui.FieldMenuPresentation")

local FieldMenuState = {}
FieldMenuState.__index = FieldMenuState

local function panel(x, y, width, height)
  love.graphics.setColor(0.96, 0.98, 0.94, 1)
  love.graphics.rectangle("fill", x, y, width, height)
  love.graphics.setColor(0.08, 0.1, 0.12, 1)
  love.graphics.rectangle("line", x, y, width, height)
  love.graphics.rectangle("line", x + 2, y + 2, width - 4, height - 4)
end

function FieldMenuState.new(gameSession, battleData, options)
  options = options or {}
  return setmetatable({
    opaque = false,
    presentation = FieldMenuPresentation.new(
      gameSession,
      battleData,
      { onClose = options.onClose }
    ),
  }, FieldMenuState)
end

function FieldMenuState:update(_, input)
  self.presentation:update(input)
end

function FieldMenuState:draw()
  local model = self.presentation:model()
  love.graphics.setColor(0, 0, 0, 0.38)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  panel(8, 6, 144, 132)
  love.graphics.printf(model.title, 14, 12, 132, "center")
  love.graphics.setColor(0.08, 0.1, 0.12, 1)
  if model.kind == "root" then
    for index, option in ipairs(model.options) do
      local marker = index == model.selected and ">" or " "
      local suffix = option.disabled and " ---" or ""
      love.graphics.print(
        marker .. " " .. option.name .. suffix,
        38, 30 + (index - 1) * 16)
    end
    if model.notice then
      love.graphics.printf(model.notice, 16, 114, 128, "center")
    end
  elseif model.kind == "pack" then
    if model.empty then
      love.graphics.printf("THE PACK IS EMPTY.", 16, 54, 128, "center")
    else
      local first = math.max(1, math.min(
        math.max(1, #model.options - 8), model.selected - 4))
      for index = first, math.min(#model.options, first + 8) do
        local option = model.options[index]
        local marker = index == model.selected and ">" or " "
        love.graphics.print(
          marker .. option.name .. " x" .. option.quantity,
          17, 29 + (index - first) * 11)
      end
    end
  elseif model.kind == "party" then
    if model.empty then
      love.graphics.printf("NO POKéMON.", 16, 54, 128, "center")
    else
      for index, option in ipairs(model.options) do
        local marker = index == model.selected and ">" or " "
        love.graphics.print(
          ("%s%s L%d  %d/%d"):format(
            marker, option.name, option.level, option.hp, option.maxHP),
          15, 28 + (index - 1) * 15)
        if option.heldItem then
          love.graphics.print(
            "  HOLD " .. option.heldItem,
            21, 35 + (index - 1) * 15)
        end
      end
    end
  else
    love.graphics.print(
      ("SEEN %d  OWN %d"):format(model.seen, model.caught),
      18, 28)
    local first = math.max(1, math.min(
      #model.options - 7, model.selected - 3))
    for index = first, math.min(#model.options, first + 7) do
      local option = model.options[index]
      local marker = index == model.selected and ">" or " "
      local caught = option.caught and "*" or " "
      love.graphics.print(
        ("%s%03d %s %s"):format(
          marker, option.number, caught, option.name),
        16, 44 + (index - first) * 10)
    end
  end
  love.graphics.print("X: BACK", 94, 124)
end

return FieldMenuState
