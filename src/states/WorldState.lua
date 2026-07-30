local MapRepository = require("src.world.MapRepository")
local MapPresentationRuntime =
  require("src.script.MapPresentationRuntime")
local TileRenderer = require("src.render.TileRenderer")
local TimeOfDay = require("src.world.TimeOfDay")
local World = require("src.world.World")

local WorldState = {}
WorldState.__index = WorldState

function WorldState.new(worldData, options)
  options = options or {}
  local repository = MapRepository.new(worldData)
  local timeProvider =
    options.timeProvider or TimeOfDay.new(options.timeOfDay)
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
  }, WorldState)
  if options.scripts ~= false then
    self.scripts = MapPresentationRuntime.new(self.world, {
      state = options.scriptState,
      gameSession = options.gameSession,
      textCatalog = options.textCatalog,
    })
  end
  self.gameSession = options.gameSession
  if self.gameSession then self.gameSession:captureWorld(self.world) end
  return self
end

function WorldState:update(dt, input)
  if self.scripts and self.scripts:isBusy() then
    self.scripts:updateActive(dt, input)
  else
    self.world:update(dt, input)
    if self.scripts then self.scripts:updateIdle(input) end
  end
  if self.gameSession then self.gameSession:captureWorld(self.world) end
end

function WorldState:draw()
  self.renderer:draw(self.world)
  if self.scripts then self.scripts:draw() end
end

return WorldState
