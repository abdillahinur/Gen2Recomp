local ActorCommandHandlers =
  require("src.script.ActorCommandHandlers")
local AudioService = require("src.script.AudioService")
local BattleService = require("src.script.BattleService")
local CoreCommandHandlers =
  require("src.script.CoreCommandHandlers")
local DialogueService = require("src.script.DialogueService")
local GameplayCommandHandlers =
  require("src.script.GameplayCommandHandlers")
local InventoryService = require("src.script.InventoryService")
local PartyService = require("src.script.PartyService")
local PhoneService = require("src.script.PhoneService")
local ProgressionCommandHandlers =
  require("src.script.ProgressionCommandHandlers")
local ScriptRunner = require("src.script.ScriptRunner")
local ScriptState = require("src.script.ScriptState")

local MapScriptSession = {}
MapScriptSession.__index = MapScriptSession

function MapScriptSession.new(world, definition, options)
  options = options or {}
  local state = options.state or ScriptState.new()
  local dialogue = options.dialogue or DialogueService.new()
  local audio = options.audio or AudioService.new()
  local battles = options.battles or BattleService.new()
  local party = options.party or PartyService.new()
  local inventory = options.inventory or InventoryService.new()
  local phone = options.phone or PhoneService.new()
  local runner = ScriptRunner.new()

  for _, actor in ipairs(definition.actors or {}) do
    world.actors:bind(actor.id, actor.mapId, actor.objectId)
  end
  CoreCommandHandlers.install(runner, {
    state = state,
    dialogue = dialogue,
  })
  ActorCommandHandlers.install(runner, { actors = world.actors })
  GameplayCommandHandlers.install(runner, {
    world = world,
    actors = world.actors,
    battles = battles,
    audio = audio,
  })
  ProgressionCommandHandlers.install(runner, {
    party = party,
    inventory = inventory,
    phone = phone,
  })

  return setmetatable({
    world = world,
    definition = definition,
    runner = runner,
    state = state,
    dialogue = dialogue,
    audio = audio,
    battles = battles,
    party = party,
    inventory = inventory,
    phone = phone,
    tasks = {},
    noInput = { down = function() return false end },
  }, MapScriptSession)
end

function MapScriptSession:run(kind, id)
  local group = self.definition.behavior[kind]
  local behavior = group and group[id]
  if type(behavior) ~= "function" then
    error(("map behavior is unavailable: %s/%s"):format(kind, id), 2)
  end
  local taskId = kind .. ":" .. id .. ":" .. (#self.tasks + 1)
  local task = self.runner:start(taskId, behavior)
  self.tasks[#self.tasks + 1] = task
  return task
end

function MapScriptSession:update(dt)
  self.world:update(dt, self.noInput)
  self.runner:update(dt)
end

return MapScriptSession
