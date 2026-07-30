local StateStack = {}
StateStack.__index = StateStack

local function call(state, method, ...)
  if state and type(state[method]) == "function" then
    return state[method](state, ...)
  end
end

function StateStack.new()
  return setmetatable({ states = {} }, StateStack)
end

function StateStack:size()
  return #self.states
end

function StateStack:current()
  return self.states[#self.states]
end

function StateStack:push(state, ...)
  assert(type(state) == "table", "state must be a table")
  call(self:current(), "pause")
  table.insert(self.states, state)
  call(state, "enter", ...)
  return state
end

function StateStack:pop(...)
  local state = self:current()
  if not state then
    return nil
  end

  call(state, "exit", ...)
  table.remove(self.states)
  call(self:current(), "resume")
  return state
end

function StateStack:replace(state, ...)
  assert(type(state) == "table", "state must be a table")
  local current = self:current()
  if current then
    call(current, "exit")
    self.states[#self.states] = state
  else
    self.states[1] = state
  end
  call(state, "enter", ...)
  return state
end

function StateStack:clear()
  while self:current() do
    local state = self:current()
    call(state, "exit")
    table.remove(self.states)
  end
end

function StateStack:update(...)
  return call(self:current(), "update", ...)
end

function StateStack:draw(...)
  local first = 1
  for index = #self.states, 1, -1 do
    if self.states[index].opaque ~= false then
      first = index
      break
    end
  end

  for index = first, #self.states do
    call(self.states[index], "draw", ...)
  end
end

return StateStack

