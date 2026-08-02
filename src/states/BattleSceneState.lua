local BattlePresentation = require("src.ui.BattlePresentation")
local BattleSceneRenderer = require("src.render.BattleSceneRenderer")

local BattleSceneState = {}
BattleSceneState.__index = BattleSceneState

function BattleSceneState.new(session, options)
  options = options or {}
  local renderer = nil
  if options.battlePics then
    renderer = BattleSceneRenderer.new(options.battlePics, {
      graphics = options.graphics,
      image = options.image,
    })
  elseif options.renderer then
    renderer = options.renderer
  end
  return setmetatable({
    opaque = true,
    session = session,
    presentation = BattlePresentation.new(session, options),
    renderer = renderer,
    audio = options.audio,
    audioRuntime = options.audioRuntime,
    gender = options.gender,
  }, BattleSceneState)
end

function BattleSceneState:enter()
  if self.audio then
    self.audio:playMusic("crystal.music.battle")
    self.audio:playCry(
      self.session.state.opponent:active().speciesId)
    self.audio:playCry(
      self.session.state.player:active().speciesId)
  end
end

function BattleSceneState:update(_, input)
  self.presentation:update(input)
  if self.audioRuntime then self.audioRuntime:update() end
end

function BattleSceneState:draw()
  if self.renderer then
    self.renderer:draw(self.session, {
      gender = self.gender,
    })
  else
    -- Structural fallback when ROM battle pics were not supplied.
    love.graphics.setColor(0.78, 0.88, 0.76, 1)
    love.graphics.rectangle("fill", 0, 0, 160, 144)
    love.graphics.setColor(0.55, 0.68, 0.53, 1)
    love.graphics.ellipse("fill", 119, 63, 35, 8)
    love.graphics.ellipse("fill", 42, 91, 38, 9)
    love.graphics.setColor(0.2, 0.28, 0.34, 1)
    love.graphics.ellipse("fill", 119, 50, 20, 15)
    love.graphics.ellipse("fill", 40, 78, 20, 15)
  end
  self.presentation:draw()
end

return BattleSceneState
