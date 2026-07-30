local AudioService = {}
AudioService.__index = AudioService

local function requireId(id)
  if type(id) ~= "string" or id == "" then
    error("audio service: audio id must be a non-empty string", 3)
  end
end

function AudioService.new()
  return setmetatable({
    currentMusic = nil,
    events = {},
  }, AudioService)
end

function AudioService:_record(kind, id, options)
  self.events[#self.events + 1] = {
    kind = kind,
    id = id,
    options = options or {},
  }
end

function AudioService:playMusic(id, options)
  requireId(id)
  self.currentMusic = id
  self:_record("music", id, options)
end

function AudioService:stopMusic(options)
  self:_record("music_stop", self.currentMusic, options)
  self.currentMusic = nil
end

function AudioService:playSfx(id, options)
  requireId(id)
  self:_record("sfx", id, options)
end

function AudioService:playCry(id, options)
  requireId(id)
  self:_record("cry", id, options)
end

return AudioService
