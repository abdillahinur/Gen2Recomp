return function(test, equal, truthy, raises)
  local EncounterTable = require("src.world.EncounterTable")

  local function rng(values)
    return {
      index = 0,
      nextByte = function(self)
        self.index = self.index + 1
        return values[self.index]
      end,
    }
  end

  local function data()
    local function slots(base, count, weights)
      local result = {}
      for index = 1, count do
        result[index] = {
          level = base + index,
          speciesNumber = base + index,
          weight = weights[index],
        }
      end
      return result
    end
    return {
      maps = {
        {
          mapId = "24:3",
          grass = {
            rates = { morning = 25, day = 20, night = 15 },
            periods = {
              morning = slots(10, 7, { 30, 30, 20, 10, 5, 4, 1 }),
              day = slots(20, 7, { 30, 30, 20, 10, 5, 4, 1 }),
              night = slots(30, 7, { 30, 30, 20, 10, 5, 4, 1 }),
            },
          },
          water = {
            rate = 15,
            slots = slots(40, 3, { 60, 30, 10 }),
          },
        },
      },
    }
  end

  test("encounter table selects period-weighted grass slots", function()
    local encounters = EncounterTable.new(data())
    local request = encounters:roll(
      "24:3", "night", "grass", rng({ 0, 94, 7 }))
    truthy(request)
    equal(request.kind, "wild")
    equal(request.options.speciesNumber, 35)
    equal(request.options.level, 35)
    equal(request.options.encounter.period, "night")
    equal(request.options.encounter.terrain, "grass")
    equal(request.options.seed, 7)
  end)

  test("encounter table applies native water slot and level rolls", function()
    local encounters = EncounterTable.new(data())
    local request = encounters:roll(
      "24:3", "day", "water", rng({ 0, 99, 250, 9 }))
    equal(request.options.speciesNumber, 43)
    equal(request.options.level, 47)
    equal(request.options.encounter.terrain, "water")

    truthy(encounters:roll(
      "24:3", "day", "grass", rng({ 20 })) == nil)
    truthy(encounters:roll(
      "1:1", "day", "grass", rng({})) == nil)
  end)

  test("encounter terrain recognizes Crystal grass and water", function()
    equal(EncounterTable.terrainForCollision(0x18), "grass")
    equal(EncounterTable.terrainForCollision(0x4c), "grass")
    equal(EncounterTable.terrainForCollision(0x29), "water")
    truthy(EncounterTable.terrainForCollision(0x00) == nil)
    raises(function()
      EncounterTable.new(data()):roll(
        "24:3", "dark", "grass", rng({}))
    end, "period")
  end)
end
