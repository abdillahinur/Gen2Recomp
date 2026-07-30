return function(test, equal, truthy, raises)
  local GameSession = require("src.game.GameSession")
  local MemoryFilesystem = require("tests.fixtures.MemoryFilesystem")
  local NativeSaveCodec = require("src.save.NativeSaveCodec")
  local RtcPersistence = require("src.save.RtcPersistence")
  local SaveStore = require("src.save.SaveStore")

  local function snapshot()
    local game = GameSession.new("crystal_us_11", {
      money = 1234,
      clock = { hour = 23, minute = 50, weekday = 6 },
      player = { mapId = "10:5", x = 4, y = 7, facing = "left" },
    })
    game.party:give("crystal.species.cyndaquil", 5)
    return game:snapshot()
  end

  test("native save codec binds checksum schema and ROM profile",
    function()
      local encoded = NativeSaveCodec.encode(
        "crystal_us_11", snapshot(), 1000)
      local decoded, savedAt =
        NativeSaveCodec.decode(encoded, "crystal_us_11")
      equal(savedAt, 1000)
      equal(decoded.money, 1234)
      raises(function()
        NativeSaveCodec.decode(encoded, "crystal_us_10")
      end, "profile mismatch")
      raises(function()
        NativeSaveCodec.decode(
          encoded:gsub('"money":1234', '"money":1235'),
          "crystal_us_11"
        )
      end, "checksum mismatch")
    end)

  test("RTC reconciliation advances time and weekday safely",
    function()
      local result, report =
        RtcPersistence.reconcile(snapshot(), 1000, 1000 + 90000)
      equal(result.clock.hour, 0)
      equal(result.clock.minute, 50)
      equal(result.clock.weekday, 1)
      equal(report.elapsedSeconds, 90000)
      local backward, warning =
        RtcPersistence.reconcile(snapshot(), 2000, 1000)
      equal(backward.clock.hour, 23)
      truthy(warning.hostClockMovedBackward)
    end)

  test("save store writes atomically and loads its backup",
    function()
      local filesystem = MemoryFilesystem.new()
      local store = SaveStore.new(filesystem)
      truthy(store:save("crystal_us_11", snapshot(), 1000))
      local loaded, rtc, source =
        store:load("crystal_us_11", 1060)
      equal(source, "primary")
      equal(loaded.clock.hour, 23)
      equal(loaded.clock.minute, 51)
      equal(rtc.elapsedSeconds, 60)

      local newer = snapshot()
      newer.money = 999
      truthy(store:save("crystal_us_11", newer, 2000))
      filesystem:write(
        "saves/crystal_us_11.json", "{ corrupt")
      local recovered, _, recoveredFrom =
        store:load("crystal_us_11", 2000)
      equal(recoveredFrom, "backup")
      equal(recovered.money, 1234)
    end)
end
