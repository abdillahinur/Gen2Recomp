local FixedStep = require("src.core.FixedStep")
local Input = require("src.core.Input")
local StateStack = require("src.core.StateStack")
local BootstrapState = require("src.states.BootstrapState")
local LogicalCanvas = require("src.render.LogicalCanvas")

local smokeTest = os.getenv("GEN2RECOMP_SMOKE_TEST") == "1"

local input
local states
local clock
local canvas
local interpolationAlpha = 0

local function drawCanvas()
  local windowWidth, windowHeight = love.graphics.getDimensions()
  local layout = LogicalCanvas.layout(windowWidth, windowHeight)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(
    canvas,
    layout.x,
    layout.y,
    0,
    layout.scale,
    layout.scale
  )
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")

  input = Input.new()
  states = StateStack.new()
  clock = FixedStep.new({ hz = 60, maxSteps = 8 })
  canvas = LogicalCanvas.create(love.graphics)

  local romPath = os.getenv("GEN2RECOMP_ROM_PATH")
  if romPath and romPath ~= "" then
    local CrystalPreview = require("src.dev.CrystalPreview")
    local GameSession = require("src.game.GameSession")
    local IntroductionState = require("src.states.IntroductionState")
    local WorldState = require("src.states.WorldState")
    local battlePreview =
      os.getenv("GEN2RECOMP_BATTLE_PREVIEW") == "1"
    local worldData, profile, textCatalog, battleData =
      CrystalPreview.load(romPath, { battle = true })
    local DataRegistry = require("src.pokemon.DataRegistry")
    local registry = DataRegistry.new(battleData)
    local function worldState(gameSession)
      local BattleBridge = require("src.battle.BattleBridge")
      local BattleRequestFactory =
        require("src.battle.BattleRequestFactory")
      local factory = BattleRequestFactory.new(
        registry, battleData, gameSession, {
          trainers = worldData.trainers,
        })
      return WorldState.new(worldData, {
        gameSession = gameSession,
        textCatalog = textCatalog,
        battleBridge = BattleBridge.new(states, factory),
        stateStack = states,
        battleData = battleData,
      })
    end
    if battlePreview then
      local BattleSceneState = require("src.states.BattleSceneState")
      local CrystalBattleGates =
        require("src.battle.CrystalBattleGates")
      local session = CrystalBattleGates.route29Wild(
        registry, battleData, 152)
      states:push(BattleSceneState.new(session))
    elseif os.getenv("GEN2RECOMP_SKIP_INTRO") == "1" then
      states:push(worldState(GameSession.new(profile.id)))
    else
      states:push(IntroductionState.new({
        textCatalog = textCatalog,
        onComplete = function(_, session)
          local gameSession = GameSession.new(profile.id, {
            state = session.state,
          })
          states:replace(worldState(gameSession))
        end,
      }))
    end
  else
    states:push(BootstrapState.new())
  end
end

function love.update(dt)
  local _, alpha = clock:update(dt, function(step)
    input:beginStep()
    states:update(step, input)
    input:endStep()
  end)
  interpolationAlpha = alpha

end

function love.draw()
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.04, 0.055, 0.08, 1)
  states:draw(interpolationAlpha)
  love.graphics.setCanvas()

  love.graphics.clear(0.012, 0.016, 0.024, 1)
  drawCanvas()

  if smokeTest and clock.totalSteps >= 1 then
    print("Gen2Recomp LÖVE smoke test passed.")
    love.event.quit(0)
  end
end

function love.keypressed(key, scancode, isrepeat)
  input:keypressed(key, isrepeat)
end

function love.keyreleased(key)
  input:keyreleased(key)
end

function love.focus(focused)
  if not focused then
    input:releaseAll()
  end
end
