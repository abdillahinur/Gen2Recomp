local EncounterController = require("src.world.EncounterController")
local FacilityService = require("src.game.FacilityService")
local FacilityState = require("src.states.FacilityState")
local FieldMenuState = require("src.states.FieldMenuState")
local MapRepository = require("src.world.MapRepository")
local MapPresentationRuntime =
  require("src.script.MapPresentationRuntime")
local TileRenderer = require("src.render.TileRenderer")
local TimeOfDay = require("src.world.TimeOfDay")
local TrainerController = require("src.world.TrainerController")
local World = require("src.world.World")

local WorldState = {}
WorldState.__index = WorldState

local FACILITIES = {
  ["26:4"] = { kind = "mart", catalogId = "cherrygrove" },
  ["26:5"] = { kind = "center" },
  ["10:6"] = { kind = "mart", catalogId = "violet" },
  ["10:10"] = { kind = "center" },
}

local function createTimeProvider(options)
  if options.timeProvider then return options.timeProvider end
  local timeOfDay = options.timeOfDay
  if not timeOfDay and options.gameSession then
    timeOfDay = {
      clock = function()
        return { hour = options.gameSession.clock.hour }
      end,
    }
  end
  return TimeOfDay.new(timeOfDay)
end

function WorldState.new(worldData, options)
  options = options or {}
  local repository = MapRepository.new(worldData)
  local timeProvider = createTimeProvider(options)
  local self = setmetatable({
    opaque = true,
    world = World.new(worldData, {
      repository = repository,
      playerSpriteId = options.playerSpriteId,
    }),
    renderer = TileRenderer.new(
      repository,
      worldData,
      timeProvider
    ),
    stateStack = options.stateStack,
    battleData = options.battleData,
  }, WorldState)
  if options.scripts ~= false then
    self.scripts = MapPresentationRuntime.new(self.world, {
      state = options.scriptState,
      gameSession = options.gameSession,
      textCatalog = options.textCatalog,
      battleBridge = options.battleBridge,
    })
  end
  self.gameSession = options.gameSession
  if worldData.encounters and options.battleBridge then
    self.encounters = EncounterController.new(
      worldData.encounters,
      options.battleBridge,
      timeProvider,
      {
        rng = options.encounterRng,
        seed = options.encounterSeed,
        canStart = function()
          local party = self.gameSession and self.gameSession.party
          if not party then return false end
          for _, member in ipairs(party.members) do
            if member.currentHP == nil or member.currentHP > 0 then
              return true
            end
          end
          return false
        end,
      }
    )
  end
  if worldData.trainers and options.battleBridge
      and self.gameSession then
    self.trainers = TrainerController.new(
      self.world,
      options.battleBridge,
      self.gameSession,
      {
        rng = options.trainerRng,
        seed = options.trainerSeed,
      }
    )
  end
  if self.gameSession then self.gameSession:captureWorld(self.world) end
  return self
end

function WorldState:_openFacility()
  local facility = FACILITIES[self.world.currentMapId]
  if not facility or not self.stateStack or not self.gameSession
      or not self.battleData then
    return false
  end
  local vector = ({
    up = { x = 0, y = -1 },
    down = { x = 0, y = 1 },
    left = { x = -1, y = 0 },
    right = { x = 1, y = 0 },
  })[self.world.player.facing]
  local targetX = self.world.player.x + vector.x
  local targetY = self.world.player.y + vector.y
  local clerk
  for _, object in ipairs(self.world:currentObjects()) do
    if object.id == 1 and object.visible
        and object.x == targetX and object.y == targetY then
      clerk = object
      break
    end
  end
  if not clerk then return false end
  local catalogId = facility.catalogId
  if catalogId == "cherrygrove"
      and self.gameSession.state:hasFlag(
        "crystal.story.gave_mystery_egg_to_elm") then
    catalogId = "cherrygrove_dex"
  end
  local stack = self.stateStack
  local state
  state = FacilityState.new(
    facility.kind,
    FacilityService.new(self.gameSession, self.battleData),
    {
      catalogId = catalogId,
      onClose = function()
        if stack:current() == state then stack:pop() end
      end,
    }
  )
  stack:push(state)
  return true
end

function WorldState:_openFieldMenu()
  if not self.stateStack or not self.gameSession
      or not self.battleData then
    return false
  end
  local stack = self.stateStack
  local menu
  menu = FieldMenuState.new(
    self.gameSession,
    self.battleData,
    {
      onClose = function()
        if stack:current() == menu then stack:pop() end
      end,
    }
  )
  stack:push(menu)
  return true
end

function WorldState:update(dt, input)
  if self.trainers and self.trainers:isBusy() then
    self.trainers:update(dt)
  elseif self.scripts and self.scripts:isBusy() then
    self.scripts:updateActive(dt, input)
  elseif input and input:wasPressed("start")
      and self:_openFieldMenu() then
    return
  elseif input and input:wasPressed("confirm")
      and self:_openFacility() then
    return
  else
    self.world:update(dt, input)
    if self.scripts then self.scripts:updateIdle(input) end
    local trainerStarted = self.trainers
      and self.trainers:afterStep(
        not self.scripts or not self.scripts:isBusy()
      )
    if self.encounters then
      self.encounters:afterStep(
        self.world,
        not trainerStarted
          and (not self.scripts or not self.scripts:isBusy())
      )
    end
  end
  if self.gameSession then self.gameSession:captureWorld(self.world) end
end

function WorldState:draw()
  self.renderer:draw(self.world)
  if self.scripts then self.scripts:draw() end
end

return WorldState
