local CommandRequest = require("src.script.CommandRequest")

local ScriptRunner = {}
ScriptRunner.__index = ScriptRunner

local WAIT_PROTOCOL = "gen2recomp.wait.v1"
local FINAL_STATES = {
  completed = true,
  failed = true,
  cancelled = true,
}

local function fail(message, level)
  error("script runner: " .. message, level or 3)
end

local function traceback(thread, message)
  if debug and debug.traceback then
    local ok, result = pcall(debug.traceback, thread, tostring(message))
    if ok then return result end
  end
  return tostring(message)
end

local function setState(runner, task, state)
  task.state = state
  if runner.onStateChanged then
    runner.onStateChanged(task, state)
  end
end

local function failTask(runner, task, message)
  task.error = traceback(task.coroutine, message)
  task.wait = nil
  setState(runner, task, "failed")
end

local function completeTask(runner, task, result)
  task.result = result
  task.wait = nil
  setState(runner, task, "completed")
end

local function dispatch(runner, task, request)
  local handler = runner.handlers[request.name]
  if not handler then
    failTask(runner, task, "no handler for command " .. request.name)
    return false
  end
  local ok, result = pcall(
    handler,
    request.arguments,
    task.context,
    task
  )
  if not ok then
    failTask(runner, task,
      "command " .. request.name .. " failed: " .. tostring(result))
    return false
  end
  if type(result) == "table" and result.protocol == WAIT_PROTOCOL then
    task.wait = result
    setState(runner, task, "waiting")
    return false
  end
  return true, result
end

local function advance(runner, task, initialValue)
  local value = initialValue
  local resumes = 0
  while not FINAL_STATES[task.state] do
    resumes = resumes + 1
    if resumes > runner.maxImmediateResumes then
      failTask(runner, task,
        "immediate command limit exceeded; possible infinite script")
      return
    end
    setState(runner, task, "running")
    local resumed = { coroutine.resume(task.coroutine, value) }
    local ok = table.remove(resumed, 1)
    if not ok then
      failTask(runner, task, resumed[1])
      return
    end
    if coroutine.status(task.coroutine) == "dead" then
      completeTask(runner, task, resumed[1])
      return
    end
    local yielded = resumed[1]
    if not CommandRequest.validate(yielded) then
      failTask(runner, task, "script yielded an invalid command request")
      return
    end
    task.lastCommand = yielded.name
    local immediate, commandResult = dispatch(runner, task, yielded)
    if not immediate then return end
    value = commandResult
  end
end

function ScriptRunner.wait(update, cancel)
  if type(update) ~= "function" then
    fail("wait update must be a function", 2)
  end
  if cancel ~= nil and type(cancel) ~= "function" then
    fail("wait cancel must be a function or nil", 2)
  end
  return {
    protocol = WAIT_PROTOCOL,
    update = update,
    cancel = cancel,
  }
end

function ScriptRunner.new(options)
  options = options or {}
  local maxImmediateResumes = options.maxImmediateResumes or 100
  if type(maxImmediateResumes) ~= "number"
      or maxImmediateResumes < 1
      or maxImmediateResumes % 1 ~= 0 then
    fail("maxImmediateResumes must be a positive integer", 2)
  end
  return setmetatable({
    handlers = options.handlers or {},
    tasks = {},
    byId = {},
    maxImmediateResumes = maxImmediateResumes,
    onStateChanged = options.onStateChanged,
  }, ScriptRunner)
end

function ScriptRunner:register(name, handler)
  CommandRequest.new(name)
  if type(handler) ~= "function" then
    fail("command handler must be a function", 2)
  end
  if self.handlers[name] then
    fail("command handler already registered: " .. name, 2)
  end
  self.handlers[name] = handler
end

function ScriptRunner:start(id, behavior, context)
  if type(id) ~= "string" or id == "" then
    fail("task id must be a non-empty string", 2)
  end
  if self.byId[id] and not FINAL_STATES[self.byId[id].state] then
    fail("task is already active: " .. id, 2)
  end
  if type(behavior) ~= "function" then
    fail("behavior must be a function", 2)
  end
  local task = {
    id = id,
    state = "ready",
    context = context or {},
    coroutine = coroutine.create(function()
      return behavior(context or {})
    end),
    wait = nil,
    result = nil,
    error = nil,
    cancellationReason = nil,
    lastCommand = nil,
  }
  self.tasks[#self.tasks + 1] = task
  self.byId[id] = task
  advance(self, task)
  return task
end

function ScriptRunner:update(dt)
  if type(dt) ~= "number" or dt < 0 then
    fail("update dt must be a non-negative number", 2)
  end
  for _, task in ipairs(self.tasks) do
    if task.state == "waiting" then
      local operation = task.wait
      local ok, done, result = pcall(
        operation.update,
        operation,
        dt,
        task.context,
        task
      )
      if not ok then
        failTask(self, task,
          "waiting command failed: " .. tostring(done))
      elseif done then
        task.wait = nil
        advance(self, task, result)
      end
    end
  end
end

function ScriptRunner:cancel(id, reason)
  local task = self.byId[id]
  if not task or FINAL_STATES[task.state] then
    return false
  end
  if task.wait and task.wait.cancel then
    local ok, message = pcall(task.wait.cancel, task.wait, task)
    if not ok then
      failTask(self, task,
        "wait cancellation failed: " .. tostring(message))
      return false
    end
  end
  task.wait = nil
  task.cancellationReason = reason or "cancelled"
  setState(self, task, "cancelled")
  return true
end

function ScriptRunner:get(id)
  return self.byId[id]
end

function ScriptRunner:isBusy()
  for _, task in ipairs(self.tasks) do
    if not FINAL_STATES[task.state] then return true end
  end
  return false
end

function ScriptRunner:isFinished(id)
  local task = self.byId[id]
  return task ~= nil and FINAL_STATES[task.state] == true
end

return ScriptRunner
