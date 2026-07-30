local BootstrapState = {}
BootstrapState.__index = BootstrapState

function BootstrapState.new()
  return setmetatable({
    opaque = true,
    x = 80,
    y = 104,
    elapsed = 0,
  }, BootstrapState)
end

function BootstrapState:update(dt, input)
  self.elapsed = self.elapsed + dt
  local speed = 36

  if input:down("left") then self.x = self.x - speed * dt end
  if input:down("right") then self.x = self.x + speed * dt end
  if input:down("up") then self.y = self.y - speed * dt end
  if input:down("down") then self.y = self.y + speed * dt end

  self.x = math.max(6, math.min(154, self.x))
  self.y = math.max(82, math.min(138, self.y))
end

function BootstrapState:draw()
  local pulse = 0.72 + math.sin(self.elapsed * 3) * 0.12

  love.graphics.setColor(0.12, 0.17, 0.25, 1)
  for x = 0, 159, 8 do
    love.graphics.line(x, 80, x, 143)
  end
  for y = 80, 143, 8 do
    love.graphics.line(0, y, 159, y)
  end

  love.graphics.setColor(0.88, 0.94, 1, 1)
  love.graphics.print("GEN2RECOMP", 6, 6)
  love.graphics.setColor(0.45, 0.76, 1, 1)
  love.graphics.print("M1 IMPORTER CORE", 6, 20)

  love.graphics.setColor(0.78, 0.82, 0.89, 1)
  love.graphics.print("Importer UI pending.", 6, 39)
  love.graphics.print("Crystal: v1.0 / v1.1", 6, 51)
  love.graphics.print("Move: arrows / WASD", 6, 65)

  love.graphics.setColor(0.35, 0.82, 1, pulse)
  love.graphics.rectangle("fill",
    math.floor(self.x) - 3,
    math.floor(self.y) - 3,
    7,
    7
  )
  love.graphics.setColor(0.8, 0.95, 1, 1)
  love.graphics.rectangle("line",
    math.floor(self.x) - 4,
    math.floor(self.y) - 4,
    9,
    9
  )
end

return BootstrapState
