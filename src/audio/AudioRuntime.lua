local AudioRuntime = {}
AudioRuntime.__index = AudioRuntime

function AudioRuntime.new(service, sink)
  return setmetatable({
    service = service,
    sink = sink,
    cursor = 0,
  }, AudioRuntime)
end

function AudioRuntime:update()
  for index = self.cursor + 1, #self.service.events do
    local event = self.service.events[index]
    if event.kind == "music" then
      self.sink:playMusic(event.id, event.options)
    elseif event.kind == "music_stop" then
      self.sink:stopMusic(event.options)
    elseif event.kind == "sfx" then
      self.sink:playSfx(event.id, event.options)
    elseif event.kind == "cry" then
      self.sink:playCry(event.id, event.options)
    end
    self.cursor = index
  end
end

return AudioRuntime
