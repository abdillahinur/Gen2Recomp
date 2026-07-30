local FacilityPresentation = {}
FacilityPresentation.__index = FacilityPresentation

local function pressed(input, action)
  return input and input:wasPressed(action)
end

local function wrap(value, maximum)
  if maximum < 1 then return 1 end
  if value < 1 then return maximum end
  if value > maximum then return 1 end
  return value
end

local function label(id)
  return tostring(id):match("([^.]+)$"):gsub("_", " "):upper()
end

local function partyOptions(service, members)
  local result = {}
  for index, member in ipairs(members) do
    local species = service.species[
      tostring(member.speciesId):match("([^.]+)$")]
    result[index] = {
      name = member.nickname or species and species.name
        or label(member.speciesId),
      level = member.level,
      hp = member.currentHP or service:maxHP(member),
      maxHP = service:maxHP(member),
    }
  end
  return result
end

function FacilityPresentation.new(kind, service, options)
  options = options or {}
  if kind ~= "center" and kind ~= "mart" then
    error("facility presentation requires center or mart", 2)
  end
  return setmetatable({
    kind = kind,
    service = service,
    catalogId = options.catalogId,
    onClose = options.onClose,
    mode = kind,
    selected = 1,
    message = nil,
    returnMode = kind,
  }, FacilityPresentation)
end

function FacilityPresentation:_setMode(mode)
  self.mode = mode
  self.selected = 1
end

function FacilityPresentation:_say(message, returnMode)
  self.message = message
  self.returnMode = returnMode or self.mode
  self.mode = "message"
end

function FacilityPresentation:_close()
  if self.onClose then self.onClose() end
end

function FacilityPresentation:_count()
  if self.mode == "center" then return 3 end
  if self.mode == "mart" then return 3 end
  if self.mode == "pc" then return 3 end
  if self.mode == "buy" then
    return #self.service:catalog(self.catalogId)
  end
  if self.mode == "sell" then
    local count = 0
    for _, quantity in pairs(self.service.game.inventory.items) do
      if quantity > 0 then count = count + 1 end
    end
    return count
  end
  if self.mode == "deposit" then
    return #self.service.game.party.members
  end
  if self.mode == "withdraw" then
    return #self.service.game.storage.pokemon
  end
  return 0
end

function FacilityPresentation:_inventory()
  local result = {}
  for id, quantity in pairs(self.service.game.inventory.items) do
    if quantity > 0 then
      result[#result + 1] = {
        id = id,
        name = label(id),
        quantity = quantity,
        price = math.floor(
          (self.service.PRICES[id] or 0) / 2),
      }
    end
  end
  table.sort(result, function(left, right) return left.id < right.id end)
  return result
end

function FacilityPresentation:update(input)
  if self.mode == "message" then
    if pressed(input, "confirm") or pressed(input, "cancel") then
      self:_setMode(self.returnMode)
    end
    return true
  end
  if pressed(input, "start") then
    self:_close()
    return true
  end
  local count = self:_count()
  if pressed(input, "up") and count > 0 then
    self.selected = wrap(self.selected - 1, count)
  elseif pressed(input, "down") and count > 0 then
    self.selected = wrap(self.selected + 1, count)
  elseif pressed(input, "cancel") then
    if self.mode == self.kind then
      self:_close()
    elseif self.mode == "pc" then
      self:_setMode("center")
    elseif self.mode == "deposit" or self.mode == "withdraw" then
      self:_setMode("pc")
    else
      self:_setMode("mart")
    end
  elseif pressed(input, "confirm") then
    if self.mode == "center" then
      if self.selected == 1 then
        self.service:healParty()
        self:_say("YOUR PARTY IS FULLY HEALED.", "center")
      elseif self.selected == 2 then
        self:_setMode("pc")
      else
        self:_close()
      end
    elseif self.mode == "mart" then
      if self.selected == 1 then self:_setMode("buy")
      elseif self.selected == 2 then self:_setMode("sell")
      else self:_close() end
    elseif self.mode == "pc" then
      if self.selected == 1 then self:_setMode("deposit")
      elseif self.selected == 2 then self:_setMode("withdraw")
      else self:_setMode("center") end
    elseif self.mode == "buy" then
      local item = self.service:catalog(self.catalogId)[self.selected]
      if item then
        local _, reason = self.service:buy(item.id, 1)
        self:_say(reason and "YOU CANNOT BUY THAT."
          or "PURCHASE COMPLETE.", "buy")
      end
    elseif self.mode == "sell" then
      local item = self:_inventory()[self.selected]
      if item then
        local _, reason = self.service:sell(item.id, 1)
        self:_say(reason and "THAT CANNOT BE SOLD."
          or "SALE COMPLETE.", "sell")
      end
    elseif self.mode == "deposit" then
      local _, reason = self.service.game.storage:depositPokemon(
        self.service.game.party, self.selected)
      self:_say(reason == "last_party_member"
        and "KEEP AT LEAST ONE POKEMON."
        or reason and "DEPOSIT FAILED."
        or "POKEMON DEPOSITED.", "deposit")
    elseif self.mode == "withdraw" then
      local _, reason = self.service.game.storage:withdrawPokemon(
        self.service.game.party, self.selected)
      self:_say(reason and "WITHDRAWAL FAILED."
        or "POKEMON WITHDRAWN.", "withdraw")
    end
  end
  return true
end

function FacilityPresentation:model()
  if self.mode == "message" then
    return { kind = "message", text = self.message }
  elseif self.mode == "center" then
    return {
      kind = "menu", title = "POKEMON CENTER",
      options = { "HEAL PARTY", "PC", "LEAVE" },
      selected = self.selected,
    }
  elseif self.mode == "mart" then
    return {
      kind = "menu", title = "MART",
      subtitle = ("MONEY $%d"):format(self.service.game.money),
      options = { "BUY", "SELL", "LEAVE" },
      selected = self.selected,
    }
  elseif self.mode == "pc" then
    return {
      kind = "menu", title = "BILL'S PC",
      options = { "DEPOSIT", "WITHDRAW", "LOG OFF" },
      selected = self.selected,
    }
  elseif self.mode == "buy" then
    local options = {}
    for index, item in ipairs(self.service:catalog(self.catalogId)) do
      options[index] = {
        name = label(item.id),
        detail = "$" .. item.price,
      }
    end
    return {
      kind = "list", title = "BUY",
      subtitle = ("MONEY $%d"):format(self.service.game.money),
      options = options, selected = self.selected,
    }
  elseif self.mode == "sell" then
    local options = {}
    for index, item in ipairs(self:_inventory()) do
      options[index] = {
        name = item.name .. " x" .. item.quantity,
        detail = "$" .. item.price,
      }
    end
    return {
      kind = "list", title = "SELL",
      subtitle = ("MONEY $%d"):format(self.service.game.money),
      options = options, selected = self.selected,
    }
  elseif self.mode == "deposit" then
    return {
      kind = "party", title = "DEPOSIT",
      options = partyOptions(
        self.service, self.service.game.party.members),
      selected = self.selected,
    }
  end
  return {
    kind = "party", title = "WITHDRAW",
    options = partyOptions(
      self.service, self.service.game.storage.pokemon),
    selected = self.selected,
  }
end

return FacilityPresentation
