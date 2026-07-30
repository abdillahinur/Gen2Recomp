local LogicalCanvas = {}

LogicalCanvas.WIDTH = 160
LogicalCanvas.HEIGHT = 144

function LogicalCanvas.layout(windowWidth, windowHeight)
  local scale = math.max(1, math.floor(math.min(
    windowWidth / LogicalCanvas.WIDTH,
    windowHeight / LogicalCanvas.HEIGHT
  )))
  local width = LogicalCanvas.WIDTH * scale
  local height = LogicalCanvas.HEIGHT * scale
  return {
    scale = scale,
    width = width,
    height = height,
    x = math.floor((windowWidth - width) / 2),
    y = math.floor((windowHeight - height) / 2),
  }
end

function LogicalCanvas.create(graphics)
  local canvas = graphics.newCanvas(
    LogicalCanvas.WIDTH,
    LogicalCanvas.HEIGHT
  )
  canvas:setFilter("nearest", "nearest")
  return canvas
end

return LogicalCanvas
