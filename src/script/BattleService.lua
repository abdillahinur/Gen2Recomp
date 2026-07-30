local ScriptRunner = require("src.script.ScriptRunner")

local BattleService = {}
BattleService.__index = BattleService

function BattleService.new()
  return setmetatable({
    active = nil,
    history = {},
  }, BattleService)
end

function BattleService:start(arguments)
  if self.active then error("battle service: a battle is already active", 2) end
  local battle = {
    kind = arguments.kind,
    opponentId = arguments.opponentId,
    options = arguments.options or {},
    resolved = false,
  }
  self.active = battle
  self.history[#self.history + 1] = battle
  return ScriptRunner.wait(
    function()
      return battle.resolved, battle.result
    end,
    function()
      battle.cancelled = true
      if self.active == battle then self.active = nil end
    end
  )
end

function BattleService:resolve(result)
  local battle = self.active
  if not battle then return false end
  battle.resolved = true
  battle.result = result
  self.active = nil
  return true
end

return BattleService
