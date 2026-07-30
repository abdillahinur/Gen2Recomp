local Camera = {}
Camera.__index = Camera

function Camera.new(width, height)
  return setmetatable({
    width = width or 160,
    height = height or 144,
    x = 0,
    y = 0,
  }, Camera)
end

function Camera:follow(x, y, worldWidth, worldHeight)
  local maximumX = math.max(0, worldWidth - self.width)
  local maximumY = math.max(0, worldHeight - self.height)
  self.x = math.max(0, math.min(maximumX,
    math.floor(x - self.width / 2)))
  self.y = math.max(0, math.min(maximumY,
    math.floor(y - self.height / 2)))
end

return Camera
