local CancellationToken = {}
CancellationToken.__index = CancellationToken

function CancellationToken.new()
  return setmetatable({
    cancelled = false,
    reason = nil,
  }, CancellationToken)
end

function CancellationToken:cancel(reason)
  if not self.cancelled then
    self.cancelled = true
    self.reason = reason or "cancelled"
  end
end

function CancellationToken:isCancelled()
  return self.cancelled
end

function CancellationToken:getReason()
  return self.reason
end

return CancellationToken
