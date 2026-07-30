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
    local freshPreview =
      os.getenv("GEN2RECOMP_FRESH_PREVIEW") == "1"
    local worldData, profile, textCatalog, battleData, presentationData =
      CrystalPreview.load(romPath, { battle = true })
    local DataRegistry = require("src.pokemon.DataRegistry")
    local registry = DataRegistry.new(battleData)
    local LoveFilesystem = require("src.core.LoveFilesystem")
    local SaveStore = require("src.save.SaveStore")
    local saveStore = SaveStore.new(LoveFilesystem.new())
    local AudioRuntime = require("src.audio.AudioRuntime")
    local AudioService = require("src.script.AudioService")
    local LoveAudioSink = require("src.audio.LoveAudioSink")
    local audio = AudioService.new()
    local audioRuntime =
      AudioRuntime.new(audio, LoveAudioSink.new())
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
        font = presentationData.font,
        battleBridge = BattleBridge.new(states, factory, {
          audio = audio,
          audioRuntime = audioRuntime,
        }),
        stateStack = states,
        battleData = battleData,
        audio = audio,
        audioRuntime = audioRuntime,
        onSave = function()
          return saveStore:save(
            profile.id, gameSession:snapshot(), os.time())
        end,
      })
    end
    if battlePreview then
      local BattleSceneState = require("src.states.BattleSceneState")
      local CrystalBattleGates =
        require("src.battle.CrystalBattleGates")
      local session = CrystalBattleGates.route29Wild(
        registry, battleData, 152)
      states:push(BattleSceneState.new(session, {
        audio = audio,
        audioRuntime = audioRuntime,
      }))
    else
      local loaded = not freshPreview
        and saveStore:load(profile.id, os.time()) or nil
      if loaded then
        states:push(worldState(GameSession.new(profile.id, {
          snapshot = loaded,
        })))
      elseif os.getenv("GEN2RECOMP_SKIP_INTRO") == "1" then
        states:push(worldState(GameSession.new(profile.id)))
      else
        states:push(IntroductionState.new({
          textCatalog = textCatalog,
          font = presentationData.font,
          audio = audio,
          audioRuntime = audioRuntime,
          onComplete = function(_, session)
            local gameSession = GameSession.new(profile.id, {
              state = session.state,
            })
            states:replace(worldState(gameSession))
          end,
        }))
      end
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
