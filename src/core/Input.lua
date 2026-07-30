local Input = {}
Input.__index = Input

local DEFAULT_BINDINGS = {
  up = { "up", "w" },
  down = { "down", "s" },
  left = { "left", "a" },
  right = { "right", "d" },
  confirm = { "z", "return", "space" },
  cancel = { "x", "backspace" },
  start = { "escape" },
  select = { "tab", "lshift", "rshift" },
}

local function copyBindings(source)
  local result = {}
  for action, keys in pairs(source) do
    result[action] = {}
    for index, key in ipairs(keys) do
      result[action][index] = key
    end
  end
  return result
end

function Input.new(bindings)
  local self = setmetatable({
    bindings = copyBindings(bindings or DEFAULT_BINDINGS),
    keyToActions = {},
    held = {},
    pendingPressed = {},
    pendingReleased = {},
    pressed = {},
    released = {},
  }, Input)

  for action, keys in pairs(self.bindings) do
    for _, key in ipairs(keys) do
      self.keyToActions[key] = self.keyToActions[key] or {}
      table.insert(self.keyToActions[key], action)
    end
  end

  return self
end

function Input:keypressed(key, isrepeat)
  local actions = self.keyToActions[key]
  if not actions then
    return
  end

  for _, action in ipairs(actions) do
    if not self.held[action] and not isrepeat then
      self.pendingPressed[action] = true
    end
    self.held[action] = true
  end
end

function Input:keyreleased(key)
  local actions = self.keyToActions[key]
  if not actions then
    return
  end

  for _, action in ipairs(actions) do
    if self.held[action] then
      self.pendingReleased[action] = true
    end
    self.held[action] = nil
  end
end

function Input:beginStep()
  self.pressed = self.pendingPressed
  self.released = self.pendingReleased
  self.pendingPressed = {}
  self.pendingReleased = {}
end

function Input:endStep()
  self.pressed = {}
  self.released = {}
end

function Input:down(action)
  return self.held[action] == true
end

function Input:wasPressed(action)
  return self.pressed[action] == true
end

function Input:wasReleased(action)
  return self.released[action] == true
end

function Input:releaseAll()
  for action in pairs(self.held) do
    self.pendingReleased[action] = true
  end
  self.held = {}
end

function Input.defaultBindings()
  return copyBindings(DEFAULT_BINDINGS)
end

return Input

