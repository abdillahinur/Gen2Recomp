local LiveFidelityDriver = {}
LiveFidelityDriver.__index = LiveFidelityDriver

local REQUIRED_CAPTURES = {
  "gender",
  "clock",
  "professor",
  "wooper",
  "naming",
  "shrink",
  "world",
}

local function emptyInput(action)
  return {
    wasPressed = function(_, candidate)
      return action ~= nil and candidate == action
    end,
    down = function()
      return false
    end,
  }
end

local function requestId(state)
  local session = state and state.session
  local request = session and session.dialogue
    and session.dialogue.active
  return request and request.id or ""
end

local function modelSignature(state, model)
  if not model then
    return state and state.endingFrame and "ending" or "idle"
  end
  return table.concat({
    model.kind or "",
    model.id or requestId(state),
    model.stage or "",
    tostring(model.page or ""),
    tostring(model.selected or ""),
  }, "|")
end

local function actionFor(model)
  if not model then return nil end
  if model.kind == "name_choice" and model.selected == 1 then
    return "down"
  end
  if model.kind == "text"
      or model.kind == "choice"
      or model.kind == "clock"
      or model.kind == "name_choice" then
    return "confirm"
  end
end

function LiveFidelityDriver.new()
  return setmetatable({
    signature = nil,
    stableFrames = 0,
    acted = false,
    captures = {},
    finished = false,
  }, LiveFidelityDriver)
end

function LiveFidelityDriver:inputFor(state)
  local presentation = state and state.presentation
  local model = presentation and presentation:model() or nil
  local signature = modelSignature(state, model)
  if signature ~= self.signature then
    self.signature = signature
    self.stableFrames = 0
    self.acted = false
    return emptyInput()
  end
  self.stableFrames = self.stableFrames + 1
  local id = requestId(state)
  local holdFrames = id == "crystal.text.introduction.oak_1"
      and 16
    or id == "crystal.text.introduction.oak_2"
      and 10
    or 2
  if self.stableFrames < holdFrames then return emptyInput() end
  if self.acted then return emptyInput() end
  self.acted = true
  return emptyInput(actionFor(model))
end

function LiveFidelityDriver:_capture(name, canvas)
  if self.captures[name] then return end
  local filename = "fidelity_" .. name .. ".png"
  local image = canvas:newImageData()
  image:encode("png", filename)
  local info = love.filesystem.getInfo(filename)
  assert(info and info.size > 100,
    "fidelity screenshot was not written: " .. filename)
  self.captures[name] = true
  print("Fidelity screenshot: "
    .. love.filesystem.getSaveDirectory() .. "/" .. filename)
end

function LiveFidelityDriver:capture(state, canvas)
  if self.finished then return end
  local presentation = state and state.presentation
  local model = presentation and presentation:model() or nil
  local id = requestId(state)

  if model and model.kind == "choice"
      and model.id == "crystal.choice.player_gender" then
    self:_capture("gender", canvas)
  elseif model and model.kind == "clock"
      and model.stage == "hour_select" then
    self:_capture("clock", canvas)
  elseif id == "crystal.text.introduction.oak_1"
      and state.visualElapsed >= 0.2 then
    self:_capture("professor", canvas)
  elseif id == "crystal.text.introduction.oak_2"
      and state.visualElapsed >= 0.1 then
    self:_capture("wooper", canvas)
  elseif model and model.kind == "name_choice" then
    self:_capture("naming", canvas)
  elseif state and state.endingFrame
      and state.endingFrame >= 8 and state.endingFrame < 28 then
    self:_capture("shrink", canvas)
  elseif state and state.world then
    self:_capture("world", canvas)
    for _, name in ipairs(REQUIRED_CAPTURES) do
      assert(self.captures[name],
        "missing fidelity screenshot stage: " .. name)
    end
    self.finished = true
    print("Gen2Recomp visible Crystal fidelity gate passed.")
    love.event.quit(0)
  end
end

return LiveFidelityDriver
