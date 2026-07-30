local BattlePresentation = require("src.ui.BattlePresentation")

local BattleSceneState = {}
BattleSceneState.__index = BattleSceneState

function BattleSceneState.new(session, options)
  options = options or {}
  return setmetatable({
    opaque = true,
    session = session,
    presentation = BattlePresentation.new(session, options),
    audio = options.audio,
    audioRuntime = options.audioRuntime,
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

local function hpBar(x, y, pokemon, width)
  local ratio = pokemon.currentHP / pokemon.stats.hp
  love.graphics.setColor(0.12, 0.15, 0.16, 1)
  love.graphics.rectangle("fill", x, y, width, 4)
  if ratio > 0.5 then
    love.graphics.setColor(0.22, 0.72, 0.32, 1)
  elseif ratio > 0.2 then
    love.graphics.setColor(0.9, 0.68, 0.18, 1)
  else
    love.graphics.setColor(0.85, 0.22, 0.2, 1)
  end
  love.graphics.rectangle("fill", x + 1, y + 1,
    math.floor((width - 2) * ratio), 2)
end

local function hud(x, y, pokemon, player)
  love.graphics.setColor(0.97, 0.98, 0.92, 1)
  love.graphics.polygon("fill",
    x, y, x + 86, y, x + 86, y + 24, x + 8, y + 24, x, y + 16)
  love.graphics.setColor(0.08, 0.1, 0.12, 1)
  love.graphics.print(pokemon.nickname, x + 7, y + 3)
  love.graphics.printf("L" .. pokemon.level, x + 52, y + 3, 28, "right")
  hpBar(x + 24, y + 14, pokemon, 54)
  if player then
    love.graphics.printf(
      pokemon.currentHP .. "/" .. pokemon.stats.hp,
      x + 37, y + 18, 41, "right")
  end
end

local function silhouette(x, y, pokemon, mirror)
  love.graphics.setColor(0.2, 0.28, 0.34, 1)
  love.graphics.ellipse("fill", x, y, 20, 15)
  love.graphics.circle("fill", x + (mirror and -9 or 9), y - 13, 10)
  love.graphics.setColor(0.78, 0.84, 0.78, 1)
  love.graphics.printf(
    pokemon.nickname:sub(1, 1),
    x - 8, y - 17, 16, "center")
end

function BattleSceneState:draw()
  love.graphics.setColor(0.78, 0.88, 0.76, 1)
  love.graphics.rectangle("fill", 0, 0, 160, 144)
  love.graphics.setColor(0.55, 0.68, 0.53, 1)
  love.graphics.ellipse("fill", 119, 63, 35, 8)
  love.graphics.ellipse("fill", 42, 91, 38, 9)

  local state = self.session.state
  local opponent = state.opponent:active()
  local player = state.player:active()
  silhouette(119, 50, opponent, false)
  silhouette(40, 78, player, true)
  hud(2, 5, opponent, false)
  hud(72, 68, player, true)
  self.presentation:draw()
end

return BattleSceneState
