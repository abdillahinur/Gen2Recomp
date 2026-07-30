local AudioService = require("src.script.AudioService")
local ClockSetupService = require("src.script.ClockSetupService")
local CoreCommandHandlers =
  require("src.script.CoreCommandHandlers")
local DialogueService = require("src.script.DialogueService")
local NameEntryService = require("src.script.NameEntryService")
local ProfileCommandHandlers =
  require("src.script.ProfileCommandHandlers")
local ScriptRunner = require("src.script.ScriptRunner")
local ScriptState = require("src.script.ScriptState")

local IntroductionSession = {}
IntroductionSession.__index = IntroductionSession

function IntroductionSession.new(definition, options)
  options = options or {}
  local state = options.state or ScriptState.new()
  local dialogue = options.dialogue or DialogueService.new()
  local clock = options.clock or ClockSetupService.new(options.clockOptions)
  local nameOptions = options.nameOptions
  if not nameOptions then
    nameOptions = {
      presets = {
        male = {
          { id = "crystal.name.chris", value = "CHRIS" },
          { id = "crystal.name.mat", value = "MAT" },
          { id = "crystal.name.allan", value = "ALLAN" },
          { id = "crystal.name.jon", value = "JON" },
        },
        female = {
          { id = "crystal.name.kris", value = "KRIS" },
          { id = "crystal.name.amanda", value = "AMANDA" },
          { id = "crystal.name.juana", value = "JUANA" },
          { id = "crystal.name.jodi", value = "JODI" },
        },
      },
    }
  end
  local names = options.names or NameEntryService.new(nameOptions)
  local audio = options.audio or AudioService.new()
  local runner = ScriptRunner.new()
  CoreCommandHandlers.install(runner, {
    state = state,
    dialogue = dialogue,
  })
  ProfileCommandHandlers.install(runner, {
    clock = clock,
    names = names,
  })
  runner:register("audio.music.play", function(arguments)
    audio:playMusic(arguments.id, arguments.options)
  end)
  runner:register("audio.cry.play", function(arguments)
    audio:playCry(arguments.id, arguments.options)
  end)
  return setmetatable({
    definition = definition,
    runner = runner,
    state = state,
    dialogue = dialogue,
    clock = clock,
    names = names,
    audio = audio,
    task = nil,
  }, IntroductionSession)
end

function IntroductionSession:start()
  if self.task and not self.runner:isFinished(self.task.id) then
    error("introduction session is already running", 2)
  end
  self.task = self.runner:start(
    "crystal.introduction",
    self.definition.behavior.run
  )
  return self.task
end

function IntroductionSession:update(dt)
  self.runner:update(dt)
end

function IntroductionSession:cancel(reason)
  if not self.task then return false end
  return self.runner:cancel(self.task.id, reason)
end

return IntroductionSession
