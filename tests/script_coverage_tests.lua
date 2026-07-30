return function(test, equal, truthy)
  local CoverageReport = require("src.script.CoverageReport")
  local ScriptCatalog = require("src.script.ScriptCatalog")

  local function events(count)
    local values = {}
    for id = 1, count do values[id] = { id = id } end
    return values
  end

  test("ScriptCatalog validates and indexes every native definition", function()
    local catalog = ScriptCatalog.load()
    equal(#catalog:all(), 3)
    truthy(catalog:get("crystal.flows.introduction"))
    equal(
      catalog:forMap("24:4").id,
      "crystal.maps.new_bark_town"
    )
    equal(
      catalog:forMap("24:5").id,
      "crystal.maps.elms_lab"
    )
    equal(catalog:forMap("24:6"), nil)
  end)

  test("CoverageReport exposes complete partial and uncovered maps", function()
    local worldData = {
      groups = {
        {
          maps = {
            {
              id = "24:4",
              group = 24,
              map = 4,
              name = "new_bark_town",
              coordEvents = events(2),
              bgEvents = events(4),
              objects = events(3),
            },
            {
              id = "24:5",
              group = 24,
              map = 5,
              name = "elms_lab",
              coordEvents = events(8),
              bgEvents = events(16),
              objects = events(6),
            },
            {
              id = "24:6",
              group = 24,
              map = 6,
              name = "players_house_1f",
              coordEvents = {},
              bgEvents = events(1),
              objects = events(1),
            },
          },
        },
      },
    }
    local report =
      CoverageReport.generate(worldData, ScriptCatalog.load())
    equal(report.summary.definitions, 3)
    equal(report.summary.flowScripts, 1)
    equal(report.summary.mapScripts, 2)
    equal(report.summary.maps.covered, 2)
    equal(report.summary.maps.available, 3)
    equal(report.summary.maps.percent, 66.7)
    equal(report.summary.callbacks.implemented, 2)
    equal(report.summary.callbacks.declared, 2)
    equal(report.summary.scenes.implemented, 4)
    equal(report.summary.scenes.declared, 4)
    equal(report.summary.scenes.flowBeats, 5)
    equal(report.summary.actors.resolved, 9)
    equal(report.summary.actors.declared, 9)
    equal(report.summary.interactions.coordEvents.declared, 6)
    equal(report.summary.interactions.coordEvents.available, 10)
    equal(report.summary.interactions.bgEvents.declared, 20)
    equal(report.summary.interactions.bgEvents.available, 21)
    equal(report.summary.interactions.objects.declared, 8)
    equal(report.summary.interactions.objects.available, 10)
    equal(report.maps[1].status, "covered")
    equal(report.maps[2].status, "partial")
    equal(report.maps[3].status, "uncovered")
  end)
end
