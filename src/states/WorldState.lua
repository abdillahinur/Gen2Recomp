local MapRepository = require("src.world.MapRepository")
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
  return setmetatable({
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
end

function WorldState:update(dt, input)
  self.world:update(dt, input)
end

function WorldState:draw()
  self.renderer:draw(self.world)
end

return WorldState
