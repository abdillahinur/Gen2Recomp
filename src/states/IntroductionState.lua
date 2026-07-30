local IntroductionSession =
  require("src.script.IntroductionSession")
local PresentationController =
  require("src.ui.PresentationController")
local RomTextProvider = require("src.ui.RomTextProvider")

local definition =
  require("data.scripts.crystal.flows.introduction")

local IntroductionState = {}
IntroductionState.__index = IntroductionState

function IntroductionState.new(options)
  options = options or {}
  local session = options.session
    or IntroductionSession.new(definition, {
      nameOptions = options.nameOptions,
      clockOptions = options.clockOptions,
      audio = options.audio,
    })
  local presentationOptions = options.presentationOptions or {}
  if options.textCatalog and not presentationOptions.textProvider then
    presentationOptions = {
      textProvider =
        RomTextProvider.forState(options.textCatalog, session.state),
      font = options.font,
    }
  elseif options.font and not presentationOptions.font then
    presentationOptions.font = options.font
  end
  return setmetatable({
    opaque = true,
    session = session,
    presentation = PresentationController.new({
      dialogue = session.dialogue,
      clock = session.clock,
      names = session.names,
    }, presentationOptions),
    onComplete = options.onComplete,
    completed = false,
    audioRuntime = options.audioRuntime,
  }, IntroductionState)
end

function IntroductionState:enter()
  if not self.session.task then self.session:start() end
end

function IntroductionState:update(dt, input)
  self.session:update(dt)
  self.presentation:update(input)
  if self.audioRuntime then self.audioRuntime:update() end
  local task = self.session.task
  if task and task.state == "completed" and not self.completed then
    self.completed = true
    if self.onComplete then
      self.onComplete(task.result, self.session)
    end
  end
end

function IntroductionState:draw()
  local request = self.session.dialogue.active
  local gender = request
    and request.id == "crystal.choice.player_gender"
  if gender then
    love.graphics.setColor(9 / 31, 30 / 31, 1, 1)
  else
    love.graphics.setColor(1, 1, 1, 1)
  end
  love.graphics.rectangle("fill", 0, 0, 160, 144)

  local task = self.session.task
  if task and task.state == "failed" then
    love.graphics.setColor(1, 0.4, 0.4, 1)
    love.graphics.printf("SCRIPT ERROR", 8, 112, 144, "center")
  end
  self.presentation:draw()
end

return IntroductionState
