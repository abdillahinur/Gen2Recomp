return function(test, equal, truthy, raises)
  local GameSession = require("src.game.GameSession")

  test("game session snapshots persistent vertical-slice state", function()
    local session = GameSession.new("crystal_us_11", {
      money = 3000,
    })
    session.state:setFlag("crystal.story.introduction_complete")
    session.state:setVariable("player.name", "NOVA")
    session.party:give(
      "crystal.species.cyndaquil",
      5,
      "crystal.item.berry"
    )
    session.inventory:give("crystal.item.potion", 2)
    session.phone:register("crystal.phone.professor_elm")
    session:setClock(10, 30, 2)
    session:markSeen("crystal.species.pidgey")
    session:markCaught("crystal.species.cyndaquil")
    session:captureWorld({
      currentMapId = "24:4",
      player = { x = 13, y = 6, facing = "down" },
    })

    local snapshot = session:snapshot()
    equal(snapshot.schema, GameSession.SCHEMA)
    equal(snapshot.profileId, "crystal_us_11")
    equal(snapshot.party[1].level, 5)
    equal(snapshot.inventory["crystal.item.potion"], 2)
    equal(snapshot.phone[1], "crystal.phone.professor_elm")
    equal(snapshot.clock.weekday, 2)
    equal(snapshot.player.mapId, "24:4")
    equal(snapshot.pokedex.caught[1], "crystal.species.cyndaquil")

    local restored = GameSession.new("crystal_us_11", {
      snapshot = snapshot,
    })
    truthy(restored.state:hasFlag(
      "crystal.story.introduction_complete"))
    equal(restored.state:getVariable("player.name"), "NOVA")
    equal(restored.party.members[1].speciesId,
      "crystal.species.cyndaquil")
    equal(restored.inventory:count("crystal.item.potion"), 2)
    truthy(restored.phone:has("crystal.phone.professor_elm"))
    truthy(restored.pokedex.seen["crystal.species.pidgey"])
    truthy(restored.pokedex.caught["crystal.species.cyndaquil"])

    restored.inventory:give("crystal.item.potion", 1)
    equal(snapshot.inventory["crystal.item.potion"], 2)
  end)

  test("game session rejects incompatible or corrupt snapshots", function()
    raises(function()
      GameSession.new("crystal_us_11", {
        snapshot = { schema = 999, profileId = "crystal_us_11" },
      })
    end, "unsupported snapshot schema")
    raises(function()
      GameSession.new("crystal_us_10", {
        snapshot = {
          schema = GameSession.SCHEMA,
          profileId = "crystal_us_11",
        },
      })
    end, "different ROM profile")
    raises(function()
      GameSession.new("crystal_us_11", { money = -1 })
    end, "money")
  end)
end
