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

-- Crystal keeps the player centered; past-edge fill comes from map
-- connections or the map's borderBlock, not from clamping the camera.
function Camera:follow(x, y)
  self.x = math.floor(x - self.width / 2)
  self.y = math.floor(y - self.height / 2)
end

return Camera
