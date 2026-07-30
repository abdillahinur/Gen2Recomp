return function(test, equal, truthy, raises)
  local RawRetentionAudit =
    require("src.import.RawRetentionAudit")
  local Rom = require("src.import.Rom")

  local function source()
    local bytes = {}
    for index = 0, 16383 do
      bytes[#bytes + 1] = string.char(
        (index * 29 + math.floor(index / 251)) % 256
      )
    end
    return table.concat(bytes)
  end

  test("RawRetentionAudit accepts normalized object graphs", function()
    local audit = RawRetentionAudit.inspect(
      Rom.new(source()),
      {
        species = {
          { id = 1, name = "A", stats = { 45, 49, 49 } },
        },
        tiles = { { 0, 1, 2, 3 } },
      }
    )
    equal(audit.status, "passed")
    truthy(audit.stringsVisited >= 4)
    equal(audit.largeStringsInspected, 0)
  end)

  test("RawRetentionAudit rejects retained raw ROM ranges", function()
    local data = source()
    raises(function()
      RawRetentionAudit.inspect(
        Rom.new(data),
        { accidentalRaw = data:sub(4097, 12288) }
      )
    end, "retains a 8192%-byte raw ROM range")

    raises(function()
      RawRetentionAudit.inspect(
        Rom.new(data),
        {
          wrapped = string.rep("x", 5120)
            .. data:sub(4097, 12288)
            .. string.rep("y", 5120),
        }
      )
    end, "retains a raw ROM window")
  end)

  test("RawRetentionAudit validates its scan configuration", function()
    raises(function()
      RawRetentionAudit.inspect(Rom.new(""), {}, {
        windowBytes = 1024,
        strideBytes = 2048,
      })
    end, "cannot exceed")
    raises(function()
      RawRetentionAudit.inspect(nil, {})
    end, "ROM reader")
    truthy(true)
  end)
end
