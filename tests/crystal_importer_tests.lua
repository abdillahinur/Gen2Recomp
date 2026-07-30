return function(test, equal, truthy, raises)
  local CacheManifest = require("src.import.CacheManifest")
  local CacheStore = require("src.import.CacheStore")
  local CancellationToken = require("src.core.CancellationToken")
  local CrystalImporter = require("src.import.CrystalImporter")
  local Json = require("src.core.Json")
  local MemoryFilesystem = require("tests.fixtures.MemoryFilesystem")

  local profile = {
    id = "crystal_import_test",
    family = "crystal",
    displayName = "Crystal import test",
    sha1 = "0123456789abcdef0123456789abcdef01234567",
    cacheSchema = 1,
    reference = {
      repository = "https://example.invalid/reference",
      sourceCommit = string.rep("a", 40),
      symbolsCommit = string.rep("b", 40),
      rgbdsVersion = "test",
    },
  }
  local buildInfo = {
    applicationId = "gen2recomp",
    applicationVersion = "import-test",
    importerVersion = 1,
  }

  local function identifier(accepted)
    return {
      inspect = function()
        return {
          accepted = accepted ~= false,
          size = 16,
          sha1 = profile.sha1,
          profile = accepted == false and nil or profile,
          header = {
            title = "TEST",
            manufacturerCode = "TEST",
            cgbFlag = 0xc0,
            cartridgeType = 0x10,
            romSizeCode = 0,
            ramSizeCode = 0,
            destinationCode = 1,
            version = 0,
            headerChecksumValid = true,
            globalChecksumValid = true,
          },
          errors = accepted == false and { "unsupported test ROM" } or {},
          warnings = { "synthetic fixture" },
        }
      end,
    }
  end

  local extractors = {
    font = function()
      return {
        schema = 1,
        sets = {
          { tiles = { {}, {} } },
          { tiles = { {} } },
        },
      }
    end,
    species = function()
      return {
        schema = 1,
        count = 2,
        records = { { id = 1 }, { id = 2 } },
      }
    end,
    tileset = function()
      return {
        schema = 1,
        id = "johto",
        graphics = { tileCount = 3, tiles = { {}, {}, {} } },
        tileSlots = { {}, {}, {}, {} },
        metatiles = { count = 5, records = {} },
        collision = { count = 5, records = {} },
      }
    end,
  }

  local function store(filesystem)
    return CacheStore.new(filesystem, {
      buildInfo = buildInfo,
      tokenFactory = function() return "import" end,
    })
  end

  test("CrystalImporter writes normalized payloads and report", function()
    local filesystem = MemoryFilesystem.new()
    local progress = {}
    local result = CrystalImporter.run(
      string.rep("\0", 16),
      store(filesystem),
      {
        identifier = identifier(),
        extractors = extractors,
        onProgress = function(event)
          progress[#progress + 1] = event
        end,
      }
    )

    truthy(result.ok)
    equal(result.cache.status, "promoted")
    equal(result.cache.fileCount, 4)
    equal(result.report.status, "complete")
    equal(result.report.sections[1].tileCount, 3)
    equal(result.report.sections[2].recordCount, 2)
    equal(result.report.sections[3].graphicTileCount, 3)
    equal(result.report.sections[3].tileSlotCount, 4)
    equal(result.report.warnings[1], "synthetic fixture")
    equal(result.report.rawRetentionAudit.status, "passed")

    equal(progress[1].fraction, 0)
    equal(progress[#progress].fraction, 1)
    equal(progress[#progress].step, "complete")
    for index = 2, #progress do
      truthy(progress[index].fraction >= progress[index - 1].fraction)
    end

    local target = CacheManifest.directory(profile, buildInfo)
    local reportSource =
      filesystem:read(target .. "/reports/import.json")
    local cachedReport = Json.decode(reportSource)
    equal(cachedReport.status, "complete")
    equal(cachedReport.rom.sha1, profile.sha1)
    truthy(filesystem:info(target .. "/data/font.json"))
    truthy(filesystem:info(target .. "/data/species.json"))
    truthy(filesystem:info(target .. "/data/tilesets/johto.json"))
  end)

  test("CrystalImporter returns a structural rejection report", function()
    local filesystem = MemoryFilesystem.new()
    local progress = {}
    local result = CrystalImporter.run(
      string.rep("\0", 16),
      store(filesystem),
      {
        identifier = identifier(false),
        extractors = extractors,
        onProgress = function(event)
          progress[#progress + 1] = event
        end,
      }
    )

    truthy(not result.ok)
    equal(result.report.status, "rejected")
    equal(result.report.errors[1], "unsupported test ROM")
    equal(progress[#progress].step, "rejected")
    equal(progress[#progress].fraction, 1)
    truthy(not filesystem:info("cache"))
  end)

  test("CrystalImporter honors cancellation between stages", function()
    local filesystem = MemoryFilesystem.new()
    local token = CancellationToken.new()
    raises(function()
      CrystalImporter.run(
        string.rep("\0", 16),
        store(filesystem),
        {
          identifier = identifier(),
          extractors = extractors,
          cancellationToken = token,
          onProgress = function(event)
            if event.step == "species" then
              token:cancel("test stop")
            end
          end,
        }
      )
    end, "test stop")
    truthy(not filesystem:info("cache"))
  end)

  test("CrystalImporter cleans staging after a cache write failure",
    function()
      local filesystem = MemoryFilesystem.new()
      local originalWrite = filesystem.write
      filesystem.write = function(self, path, data)
        if path:match("data/species%.json$") then
          return nil, "injected write failure"
        end
        return originalWrite(self, path, data)
      end

      raises(function()
        CrystalImporter.run(
          string.rep("\0", 16),
          store(filesystem),
          {
            identifier = identifier(),
            extractors = extractors,
          }
        )
      end, "injected write failure")

      local parent =
        "cache/" .. profile.id .. "/" .. profile.sha1
          .. "/schema-1"
      local items = filesystem:list(parent)
      equal(#items, 0)
    end)

  test("CrystalImporter rejects an extractor retaining raw ROM data",
    function()
      local filesystem = MemoryFilesystem.new()
      local data = {}
      for index = 1, 8192 do
        data[index] = string.char((index * 37) % 256)
      end
      data = table.concat(data)
      local unsafeExtractors = {
        font = function(rom)
          return {
            schema = 1,
            sets = {},
            accidentalRaw = rom:readString(0, rom:size()),
          }
        end,
        species = extractors.species,
        tileset = extractors.tileset,
      }

      raises(function()
        CrystalImporter.run(
          data,
          store(filesystem),
          {
            identifier = identifier(),
            extractors = unsafeExtractors,
          }
        )
      end, "retains a 8192%-byte raw ROM range")
      truthy(not filesystem:info("cache"))
    end)
end
