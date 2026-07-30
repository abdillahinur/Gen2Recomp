local FixedStep = {}
FixedStep.__index = FixedStep

function FixedStep.new(options)
  options = options or {}
  local hz = options.hz or 60
  local maxSteps = options.maxSteps or 8

  assert(type(hz) == "number" and hz > 0, "hz must be positive")
  assert(type(maxSteps) == "number" and maxSteps >= 1,
    "maxSteps must be at least one")

  return setmetatable({
    hz = hz,
    step = 1 / hz,
    maxSteps = math.floor(maxSteps),
    accumulator = 0,
    totalSteps = 0,
    droppedSteps = 0,
  }, FixedStep)
end

function FixedStep:reset()
  self.accumulator = 0
  self.totalSteps = 0
  self.droppedSteps = 0
end

function FixedStep:update(dt, runStep)
  assert(type(runStep) == "function", "runStep must be a function")

  if type(dt) ~= "number" or dt ~= dt or dt < 0 then
    dt = 0
  end

  local maximumFrame = self.step * self.maxSteps
  if dt > maximumFrame then
    dt = maximumFrame
  end

  self.accumulator = self.accumulator + dt
  local steps = 0

  while self.accumulator + 1e-12 >= self.step
      and steps < self.maxSteps do
    runStep(self.step)
    self.accumulator = self.accumulator - self.step
    self.totalSteps = self.totalSteps + 1
    steps = steps + 1
  end

  if self.accumulator >= self.step then
    local dropped = math.floor(self.accumulator / self.step)
    self.accumulator = self.accumulator - dropped * self.step
    self.droppedSteps = self.droppedSteps + dropped
  end

  return steps, self.accumulator / self.step
end

return FixedStep

