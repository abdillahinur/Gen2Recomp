local BattleEventText = require("src.ui.BattleEventText")

local BattlePresentation = {}
BattlePresentation.__index = BattlePresentation

local ROOT = { "FIGHT", "PACK", "POKéMON", "RUN" }
local OUTCOMES = {
  player_win = "YOU WON THE BATTLE!",
  opponent_win = "YOU LOST THE BATTLE.",
  draw = "THE BATTLE ENDED IN A DRAW.",
  caught = "THE WILD POKéMON WAS CAUGHT!",
  escaped = "GOT AWAY SAFELY!",
}

local function pressed(input, action)
  return input and input:wasPressed(action)
end

local function wrap(value, maximum)
  if value < 1 then return maximum end
  if value > maximum then return 1 end
  return value
end

local function copyItems(items)
  local result = {}
  for index, item in ipairs(items or {}) do
    result[index] = {
      id = item.id,
      quantity = item.quantity or 0,
    }
  end
  return result
end

function BattlePresentation.new(session, options)
  if type(session) ~= "table"
      or type(session.command) ~= "function"
      or type(session.state) ~= "table" then
    error("battle presentation requires a battle session", 2)
  end
  options = options or {}
  local opponent = session.state.opponent:active()
  local opening = session.state.kind == "wild"
    and ("A wild " .. opponent.nickname .. " appeared!")
    or (opponent.nickname .. " wants to battle!")
  return setmetatable({
    session = session,
    items = copyItems(options.items),
    onComplete = options.onComplete,
    mode = "root",
    rootIndex = 1,
    listIndex = 1,
    messages = { opening },
    eventIndex = #session.state.events,
    completed = false,
  }, BattlePresentation)
end

function BattlePresentation:_collectEvents()
  local events = self.session.state.events
  for index = self.eventIndex + 1, #events do
    local message = BattleEventText.resolve(events[index], self.session)
    if message then self.messages[#self.messages + 1] = message end
  end
  self.eventIndex = #events
end

function BattlePresentation:_root(input)
  local index = self.rootIndex
  if pressed(input, "left") or pressed(input, "right") then
    index = index % 2 == 1 and index + 1 or index - 1
  elseif pressed(input, "up") or pressed(input, "down") then
    index = index <= 2 and index + 2 or index - 2
  elseif pressed(input, "confirm") then
    if index == 1 then
      self.mode = "moves"
    elseif index == 2 then
      self.mode = "pack"
    elseif index == 3 then
      self.mode = "party"
    else
      self.session:run()
      self:_collectEvents()
    end
    self.listIndex = 1
  end
  self.rootIndex = index
end

function BattlePresentation:_moves(input)
  local moves = self.session.state.player:active().moves
  if pressed(input, "cancel") then
    self.mode = "root"
  elseif #moves > 0 and pressed(input, "up") then
    self.listIndex = wrap(self.listIndex - 1, #moves)
  elseif #moves > 0 and pressed(input, "down") then
    self.listIndex = wrap(self.listIndex + 1, #moves)
  elseif #moves > 0 and pressed(input, "confirm") then
    local slot = moves[self.listIndex]
    if slot.pp > 0 then
      self.session:command({
        kind = "move",
        moveIndex = self.listIndex,
      })
      self.mode = "root"
      self:_collectEvents()
    end
  end
end

function BattlePresentation:_party(input)
  local side = self.session.state.player
  if pressed(input, "cancel") then
    self.mode = "root"
  elseif pressed(input, "up") then
    self.listIndex = wrap(self.listIndex - 1, #side.party)
  elseif pressed(input, "down") then
    self.listIndex = wrap(self.listIndex + 1, #side.party)
  elseif pressed(input, "confirm") then
    local pokemon = side.party[self.listIndex]
    if self.listIndex ~= side.activeIndex and not pokemon:isFainted() then
      self.session:command({
        kind = "switch",
        partyIndex = self.listIndex,
      })
      self.mode = "root"
      self:_collectEvents()
    end
  end
end

function BattlePresentation:_pack(input)
  if pressed(input, "cancel") then
    self.mode = "root"
  elseif #self.items > 0 and pressed(input, "up") then
    self.listIndex = wrap(self.listIndex - 1, #self.items)
  elseif #self.items > 0 and pressed(input, "down") then
    self.listIndex = wrap(self.listIndex + 1, #self.items)
  elseif #self.items > 0 and pressed(input, "confirm") then
    local item = self.items[self.listIndex]
    if item.quantity > 0 then
      item.quantity = item.quantity - 1
      self.session:catch(item.id)
      self.mode = "root"
      self:_collectEvents()
    end
  end
end

function BattlePresentation:update(input)
  if #self.messages > 0 then
    if pressed(input, "confirm") then table.remove(self.messages, 1) end
    return true
  end
  local state = self.session.state
  if state.phase == "complete" then
    if pressed(input, "confirm") and not self.completed then
      self.completed = true
      if self.onComplete then self.onComplete(state.outcome, self.session) end
    end
    return true
  end
  if self.mode == "root" then
    self:_root(input)
  elseif self.mode == "moves" then
    self:_moves(input)
  elseif self.mode == "party" then
    self:_party(input)
  else
    self:_pack(input)
  end
  return true
end

local function pokemonModel(pokemon)
  return {
    name = pokemon.nickname,
    level = pokemon.level,
    hp = pokemon.currentHP,
    maxHP = pokemon.stats.hp,
    status = pokemon.status and pokemon.status.id or nil,
    fainted = pokemon:isFainted(),
  }
end

function BattlePresentation:model()
  if #self.messages > 0 then
    return {
      kind = "message",
      text = self.messages[1],
      remaining = #self.messages,
    }
  end
  local state = self.session.state
  if state.phase == "complete" then
    return {
      kind = "complete",
      outcome = state.outcome,
      text = OUTCOMES[state.outcome] or tostring(state.outcome):upper(),
    }
  elseif self.mode == "root" then
    return {
      kind = "root",
      options = ROOT,
      selected = self.rootIndex,
    }
  elseif self.mode == "moves" then
    local options = {}
    for index, slot in ipairs(state.player:active().moves) do
      local move = self.session.registry:get("moves", slot.id)
      options[index] = {
        name = move.name,
        pp = slot.pp,
        maxPP = slot.maxPP,
        type = move.type,
        disabled = slot.pp <= 0,
      }
    end
    return {
      kind = "moves",
      options = options,
      selected = self.listIndex,
    }
  elseif self.mode == "party" then
    local options = {}
    for index, pokemon in ipairs(state.player.party) do
      options[index] = pokemonModel(pokemon)
      options[index].active = index == state.player.activeIndex
    end
    return {
      kind = "party",
      options = options,
      selected = self.listIndex,
    }
  end
  local options = {}
  for index, item in ipairs(self.items) do
    local record = self.session.registry:get("items", item.id)
    options[index] = {
      name = record.name,
      quantity = item.quantity,
      disabled = item.quantity <= 0,
    }
  end
  return {
    kind = "pack",
    options = options,
    selected = self.listIndex,
    empty = #options == 0,
  }
end

local function panel(x, y, width, height)
  love.graphics.setColor(0.97, 0.98, 0.92, 1)
  love.graphics.rectangle("fill", x, y, width, height)
  love.graphics.setColor(0.08, 0.1, 0.12, 1)
  love.graphics.rectangle("line", x, y, width, height)
  love.graphics.rectangle("line", x + 2, y + 2, width - 4, height - 4)
end

local function marker(selected)
  return selected and "> " or "  "
end

function BattlePresentation:draw()
  local model = self:model()
  panel(2, 96, 156, 46)
  love.graphics.setColor(0.08, 0.1, 0.12, 1)
  if model.kind == "message" or model.kind == "complete" then
    love.graphics.printf(model.text, 8, 104, 144, "left")
    love.graphics.print("Z", 146, 130)
  elseif model.kind == "root" then
    for index, option in ipairs(model.options) do
      local column = (index - 1) % 2
      local row = math.floor((index - 1) / 2)
      love.graphics.print(
        marker(index == model.selected) .. option,
        12 + column * 75,
        103 + row * 16
      )
    end
  elseif model.kind == "moves" then
    for index, option in ipairs(model.options) do
      local column = (index - 1) % 2
      local row = math.floor((index - 1) / 2)
      local label = marker(index == model.selected) .. option.name
      love.graphics.printf(
        label,
        7 + column * 76,
        100 + row * 13,
        72,
        "left"
      )
    end
    local selected = model.options[model.selected]
    if selected then
      love.graphics.printf(
        ("TYPE/%s  %d/%d"):format(
          selected.type:upper(), selected.pp, selected.maxPP),
        75, 128, 78, "right"
      )
    end
  elseif model.kind == "party" then
    for index, option in ipairs(model.options) do
      local suffix = option.active and " IN" or ""
      love.graphics.print(
        marker(index == model.selected)
          .. option.name .. " " .. option.hp .. "/" .. option.maxHP
          .. suffix,
        8,
        99 + (index - 1) * 7
      )
    end
  elseif model.empty then
    love.graphics.print("THE PACK IS EMPTY.", 9, 105)
    love.graphics.print("X: BACK", 101, 130)
  else
    for index, option in ipairs(model.options) do
      love.graphics.print(
        marker(index == model.selected)
          .. option.name .. " ×" .. option.quantity,
        8,
        101 + (index - 1) * 10
      )
    end
  end
end

return BattlePresentation
