local IntroductionSession =
  require("src.script.IntroductionSession")
local PresentationController =
  require("src.ui.PresentationController")
local RomTextProvider = require("src.ui.RomTextProvider")
local CrystalIntroRenderer =
  require("src.render.CrystalIntroRenderer")

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
    endingFrame = nil,
    endingElapsed = 0,
    audioRuntime = options.audioRuntime,
    introRenderer = options.introData
      and CrystalIntroRenderer.new(options.introData) or nil,
    visualRequest = nil,
    visualElapsed = 0,
  }, IntroductionState)
end

function IntroductionState:enter()
  if not self.session.task then self.session:start() end
end

function IntroductionState:update(dt, input)
  self.session:update(dt)
  self.presentation:update(input)
  if self.audioRuntime then self.audioRuntime:update() end
  local visualRequest = self.session.dialogue.active
    or self.session.clock.active or self.session.names.active
  if visualRequest ~= self.visualRequest then
    self.visualRequest = visualRequest
    self.visualElapsed = 0
  else
    self.visualElapsed = self.visualElapsed + dt
  end
  local task = self.session.task
  if task and task.state == "completed" and not self.completed then
    if not self.endingFrame then self.endingFrame = 0 end
    self.endingElapsed = self.endingElapsed + dt
    self.endingFrame = math.floor(self.endingElapsed * 60)
    if self.endingFrame >= 102 then
      self.completed = true
      if self.onComplete then
        self.onComplete(task.result, self.session)
      end
    end
  end
end

local function dialoguePicture(request, gender)
  if not request then return nil end
  local id = request.id
  if id == "crystal.text.introduction.oak_1"
      or id == "crystal.text.introduction.oak_5" then
    return "professor"
  elseif id == "crystal.text.introduction.oak_2"
      or id == "crystal.text.introduction.oak_3"
      or id == "crystal.text.introduction.oak_4" then
    return "wooper"
  elseif id == "crystal.text.introduction.oak_6"
      or id == "crystal.text.introduction.oak_7" then
    return gender
  end
end

function IntroductionState:draw()
  local request = self.session.dialogue.active
  local gender = request
    and request.id == "crystal.choice.player_gender"
  local intro = self.introRenderer
  if self.endingFrame and intro then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    local player = self.session.state:getVariable("player.gender")
      or "male"
    local frame = self.endingFrame
    if frame < 4 then
      intro:drawPicture(player)
    elseif frame < 8 then
      intro:drawPicture("shrink1")
    elseif frame < 28 then
      intro:drawPicture("shrink2")
    else
      local alpha = frame < 78 and 1
        or math.max(0, 1 - (frame - 78) / 24)
      intro:drawPicture(player .. "Icon", {
        y = 56,
        alpha = alpha,
      })
    end
    return
  elseif gender then
    love.graphics.setColor(9 / 31, 30 / 31, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
  elseif self.session.clock.active and intro then
    intro:drawClockBackground()
  else
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
  end

  if intro and not gender and not self.session.clock.active then
    local player = self.session.state:getVariable("player.gender")
      or "male"
    local picture = dialoguePicture(request, player)
    if self.session.names.active then picture = player end
    if picture then
      local reveal = picture == "wooper"
        and math.min(1, self.visualElapsed * 12) or 1
      local alpha = picture == "professor"
        and math.min(1, self.visualElapsed * 6) or 1
      intro:drawPicture(picture, {
        x = self.session.names.active and 96 or nil,
        reveal = reveal,
        alpha = alpha,
      })
    end
  end

  local task = self.session.task
  if task and task.state == "failed" then
    love.graphics.setColor(1, 0.4, 0.4, 1)
    love.graphics.printf("SCRIPT ERROR", 8, 112, 144, "center")
  end
  self.presentation:draw()
end

return IntroductionState
