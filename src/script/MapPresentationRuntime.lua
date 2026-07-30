local AudioService = require("src.script.AudioService")
local BattleService = require("src.script.BattleService")
local DialogueService = require("src.script.DialogueService")
local InventoryService = require("src.script.InventoryService")
local MapScriptSession = require("src.script.MapScriptSession")
local PartyService = require("src.script.PartyService")
local PhoneService = require("src.script.PhoneService")
local ScriptCatalog = require("src.script.ScriptCatalog")
local ScriptState = require("src.script.ScriptState")
local PresentationController =
  require("src.ui.PresentationController")
local RomTextProvider = require("src.ui.RomTextProvider")

local MapPresentationRuntime = {}
MapPresentationRuntime.__index = MapPresentationRuntime

local VECTORS = {
  up = { x = 0, y = -1 },
  down = { x = 0, y = 1 },
  left = { x = -1, y = 0 },
  right = { x = 1, y = 0 },
}

local function completed(task)
  return task and (
    task.state == "completed"
    or task.state == "failed"
    or task.state == "cancelled"
  )
end

function MapPresentationRuntime.new(world, options)
  options = options or {}
  local gameSession = options.gameSession
  local self = setmetatable({
    world = world,
    catalog = options.catalog or ScriptCatalog.load(),
    state = options.state
      or (gameSession and gameSession.state)
      or ScriptState.new(),
    dialogue = options.dialogue or DialogueService.new(),
    audio = options.audio or AudioService.new(),
    battles = options.battles or BattleService.new(),
    party = options.party
      or (gameSession and gameSession.party)
      or PartyService.new(),
    inventory = options.inventory
      or (gameSession and gameSession.inventory)
      or InventoryService.new(),
    phone = options.phone
      or (gameSession and gameSession.phone)
      or PhoneService.new(),
    gameSession = gameSession,
    sessions = {},
    activeSession = nil,
    activeTask = nil,
    currentMapId = world.currentMapId,
    lastCoordKey = nil,
    lastError = nil,
  }, MapPresentationRuntime)
  local presentationOptions = options.presentationOptions or {}
  if options.textCatalog and not presentationOptions.textProvider then
    presentationOptions = {
      textProvider =
        RomTextProvider.forState(options.textCatalog, self.state),
    }
  end
  self.presentation = PresentationController.new({
    dialogue = self.dialogue,
  }, presentationOptions)

  for _, definition in ipairs(self.catalog:all()) do
    if definition.kind == "map" then
      local available = false
      for _, mapId in ipairs(definition.maps) do
        if world.repository:getMap(mapId) then available = true end
      end
      if available then
        local session = MapScriptSession.new(world, definition, {
          state = self.state,
          dialogue = self.dialogue,
          audio = self.audio,
          battles = self.battles,
          party = self.party,
          inventory = self.inventory,
          phone = self.phone,
        })
        for _, mapId in ipairs(definition.maps) do
          self.sessions[mapId] = session
        end
      end
    end
  end
  self:_enteredMap()
  return self
end

function MapPresentationRuntime:_start(session, kind, id)
  if not session or self.activeTask then return false end
  local task = session:run(kind, id)
  if task.state == "failed" then
    self.lastError = task.error
  elseif not completed(task) then
    self.activeSession = session
    self.activeTask = task
  end
  return true
end

function MapPresentationRuntime:_enteredMap()
  local session = self.sessions[self.world.currentMapId]
  self.currentMapId = self.world.currentMapId
  self.lastCoordKey = nil
  if not session then return end
  local callback = session.definition.coverage.callbacks[1]
  if callback then self:_start(session, "callbacks", callback) end

  if self.world.currentMapId == "24:5"
      and not self.activeTask
      and not self.state:getScene("crystal.map.elms_lab") then
    self.state:setScene(
      "crystal.map.elms_lab",
      "crystal.scene.elms_lab.meet_elm"
    )
    self:_start(
      session,
      "scenes",
      "crystal.elms_lab.scene.meet_elm"
    )
  end
end

function MapPresentationRuntime:isBusy()
  return self.activeTask ~= nil or self.presentation:isActive()
end

function MapPresentationRuntime:updateActive(dt, input)
  if self.activeSession then self.activeSession:update(dt) end
  self.presentation:update(input)
  if self.activeTask and completed(self.activeTask) then
    if self.activeTask.state == "failed" then
      self.lastError = self.activeTask.error
    end
    self.activeTask = nil
    self.activeSession = nil
  end
end

function MapPresentationRuntime:_target()
  local vector = VECTORS[self.world.player.facing]
  return self.world.player.x + vector.x,
    self.world.player.y + vector.y
end

function MapPresentationRuntime:_interact()
  local session = self.sessions[self.world.currentMapId]
  if not session then return false end
  local x, y = self:_target()
  for _, object in ipairs(self.world:currentObjects()) do
    if object.visible and object.x == x and object.y == y then
      local id = session.definition.coverage.objects[object.id]
      return id and self:_start(session, "objects", id) or false
    end
  end
  for _, event in ipairs(self.world.currentMap.bgEvents or {}) do
    if event.x == x and event.y == y then
      local id = session.definition.coverage.bgEvents[event.id]
      return id and self:_start(session, "bgEvents", id) or false
    end
  end
  return false
end

function MapPresentationRuntime:_coordBehavior()
  -- These semantic routes correspond to the source-cited event pairs in the
  -- two M3 map definitions. Positions are checked against normalized runtime
  -- coordinates; no script pointer or original event bytecode is executed.
  local mapId = self.world.currentMapId
  local x, y = self.world.player.x, self.world.player.y
  local session = self.sessions[mapId]
  if not session then return nil end
  if mapId == "24:4"
      and not self.state:hasFlag("crystal.story.got_starter") then
    if x == 1 and y == 8 then
      return session, "crystal.new_bark.coord.teacher_north"
    elseif x == 1 and y == 9 then
      return session, "crystal.new_bark.coord.teacher_south"
    end
  elseif mapId == "24:5" then
    local scene = self.state:getScene("crystal.map.elms_lab")
    if scene == "crystal.scene.elms_lab.cant_leave" and y == 6 then
      if x == 4 then
        return session, "crystal.elms_lab.coord.cant_leave_left"
      elseif x == 5 then
        return session, "crystal.elms_lab.coord.cant_leave_right"
      end
    elseif scene == "crystal.scene.elms_lab.aide_gives_potion"
        and y == 8 then
      if x == 4 then
        return session, "crystal.elms_lab.coord.aide_potion_left"
      elseif x == 5 then
        return session, "crystal.elms_lab.coord.aide_potion_right"
      end
    end
  end
end

function MapPresentationRuntime:updateIdle(input)
  if self.world.currentMapId ~= self.currentMapId then
    self:_enteredMap()
    if self.activeTask then return true end
  end
  local key = table.concat({
    self.world.currentMapId,
    self.world.player.x,
    self.world.player.y,
  }, ":")
  if key ~= self.lastCoordKey then
    self.lastCoordKey = key
    local session, id = self:_coordBehavior()
    if id then
      self:_start(session, "coordEvents", id)
      return true
    end
  end
  if not self.world.player.moving
      and input:wasPressed("confirm") then
    return self:_interact()
  end
  return false
end

function MapPresentationRuntime:draw()
  self.presentation:draw()
  if self.lastError then
    love.graphics.setColor(0.4, 0, 0, 0.9)
    love.graphics.rectangle("fill", 3, 3, 154, 16)
    love.graphics.setColor(1, 0.75, 0.75, 1)
    love.graphics.printf("MAP SCRIPT ERROR", 6, 7, 148, "center")
  end
end

return MapPresentationRuntime
