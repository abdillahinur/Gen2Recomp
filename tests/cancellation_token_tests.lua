return function(test, equal, truthy)
  local CancellationToken = require("src.core.CancellationToken")

  test("CancellationToken records the first cancellation reason", function()
    local token = CancellationToken.new()
    truthy(not token:isCancelled())
    equal(token:getReason(), nil)

    token:cancel("player closed importer")
    token:cancel("later reason")
    truthy(token:isCancelled())
    equal(token:getReason(), "player closed importer")
  end)
end
