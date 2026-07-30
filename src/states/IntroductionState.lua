local IntroductionSession =
  require("src.script.IntroductionSession")
local PresentationController =
  require("src.ui.PresentationController")

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
    })
  return setmetatable({
    opaque = true,
    session = session,
    presentation = PresentationController.new({
      dialogue = session.dialogue,
      clock = session.clock,
      names = session.names,
    }, options.presentationOptions),
    onComplete = options.onComplete,
    completed = false,
  }, IntroductionState)
end

function IntroductionState:enter()
  if not self.session.task then self.session:start() end
end

function IntroductionState:update(dt, input)
  self.session:update(dt)
  self.presentation:update(input)
  local task = self.session.task
  if task and task.state == "completed" and not self.completed then
    self.completed = true
    if self.onComplete then
      self.onComplete(task.result, self.session)
    end
  end
end

function IntroductionState:draw()
  love.graphics.setColor(0.06, 0.09, 0.16, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0.25, 0.58, 0.82, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 20)
  love.graphics.setColor(0.96, 0.98, 1, 1)
  love.graphics.printf("GEN2RECOMP", 0, 6, 160, "center")
  love.graphics.setColor(0.65, 0.75, 0.88, 1)
  love.graphics.printf(
    "CRYSTAL INTRODUCTION", 0, 38, 160, "center")
  love.graphics.setColor(0.22, 0.29, 0.4, 1)
  love.graphics.circle("fill", 80, 73, 22)
  love.graphics.setColor(0.8, 0.88, 0.96, 1)
  love.graphics.circle("line", 80, 73, 22)

  local task = self.session.task
  if task and task.state == "failed" then
    love.graphics.setColor(1, 0.4, 0.4, 1)
    love.graphics.printf("SCRIPT ERROR", 8, 112, 144, "center")
  end
  self.presentation:draw()
end

return IntroductionState
