local BattleRng = require("src.battle.BattleRng")
local EncounterTable = require("src.world.EncounterTable")

local EncounterController = {}
EncounterController.__index = EncounterController

local MAP_ENTRY_COOLDOWN = 5

function EncounterController.new(data, battleBridge, timeProvider, options)
  if type(battleBridge) ~= "table"
      or type(battleBridge.start) ~= "function" then
    error("encounter controller requires a battle bridge", 2)
  end
  if type(timeProvider) ~= "table"
      or type(timeProvider.period) ~= "function" then
    error("encounter controller requires a time provider", 2)
  end
  options = options or {}
  return setmetatable({
    table = EncounterTable.new(data),
    bridge = battleBridge,
    timeProvider = timeProvider,
    rng = options.rng or BattleRng.new(options.seed or 1),
    canStart = options.canStart or function() return true end,
    cooldown = MAP_ENTRY_COOLDOWN,
    lastStep = 0,
    lastMapId = nil,
    active = false,
    lastRequest = nil,
    lastResult = nil,
  }, EncounterController)
end

function EncounterController:afterStep(world, enabled)
  local step = world.stepCount or 0
  if step <= self.lastStep then return nil end
  self.lastStep = step

  if self.lastMapId == nil then
    self.lastMapId = world.currentMapId
  elseif self.lastMapId ~= world.currentMapId then
    self.lastMapId = world.currentMapId
    self.cooldown = MAP_ENTRY_COOLDOWN
    return nil
  end
  if not enabled or self.active then return nil end
  if self.cooldown > 0 then
    self.cooldown = self.cooldown - 1
    return nil
  end
  if not self.canStart() then return nil end

  local collisionId =
    world.grid:collisionAt(world.player.x, world.player.y)
  local terrain = EncounterTable.terrainForCollision(collisionId)
  if not terrain then return nil end
  local request = self.table:roll(
    world.currentMapId,
    self.timeProvider:period(),
    terrain,
    self.rng
  )
  if not request then return nil end

  self.active = true
  self.lastRequest = request
  local controller = self
  self.bridge:start(request, function(result)
    controller.active = false
    controller.cooldown = MAP_ENTRY_COOLDOWN
    controller.lastResult = result
  end)
  return request
end

EncounterController.MAP_ENTRY_COOLDOWN = MAP_ENTRY_COOLDOWN

return EncounterController
