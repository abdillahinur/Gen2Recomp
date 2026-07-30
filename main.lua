local FixedStep = require("src.core.FixedStep")
local Input = require("src.core.Input")
local StateStack = require("src.core.StateStack")
local BootstrapState = require("src.states.BootstrapState")

local LOGICAL_WIDTH = 160
local LOGICAL_HEIGHT = 144
local smokeTest = os.getenv("GEN2RECOMP_SMOKE_TEST") == "1"

local input
local states
local clock
local canvas
local interpolationAlpha = 0

local function drawCanvas()
  local windowWidth, windowHeight = love.graphics.getDimensions()
  local scale = math.max(1, math.floor(math.min(
    windowWidth / LOGICAL_WIDTH,
    windowHeight / LOGICAL_HEIGHT
  )))
  local drawWidth = LOGICAL_WIDTH * scale
  local drawHeight = LOGICAL_HEIGHT * scale
  local x = math.floor((windowWidth - drawWidth) / 2)
  local y = math.floor((windowHeight - drawHeight) / 2)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, x, y, 0, scale, scale)
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest")

  input = Input.new()
  states = StateStack.new()
  clock = FixedStep.new({ hz = 60, maxSteps = 8 })
  canvas = love.graphics.newCanvas(LOGICAL_WIDTH, LOGICAL_HEIGHT)
  canvas:setFilter("nearest", "nearest")

  states:push(BootstrapState.new())
end

function love.update(dt)
  local _, alpha = clock:update(dt, function(step)
    input:beginStep()
    states:update(step, input)
    input:endStep()
  end)
  interpolationAlpha = alpha

  if smokeTest and clock.totalSteps >= 3 then
    print("Gen2Recomp LÖVE smoke test passed.")
    love.event.quit(0)
  end
end

function love.draw()
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.04, 0.055, 0.08, 1)
  states:draw(interpolationAlpha)
  love.graphics.setCanvas()

  love.graphics.clear(0.012, 0.016, 0.024, 1)
  drawCanvas()
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
