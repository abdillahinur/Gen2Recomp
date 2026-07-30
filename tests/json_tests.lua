return function(test, equal, truthy, raises)
  local Json = require("src.core.Json")

  test("Json encodes objects deterministically and arrays explicitly",
    function()
      local value = {
        z = Json.array({ true, false, Json.null }),
        a = "line\nquote\"",
      }
      equal(
        Json.encode(value),
        '{"a":"line\\nquote\\"","z":[true,false,null]}'
      )
      equal(Json.encode(Json.array({})), "[]")
      equal(Json.encode({}), "{}")
    end)

  test("Json round-trips strings, numbers, objects, and arrays", function()
    local source =
      '{"array":[1,-2.5,6.02e2],"text":"snowman: \\u2603"}'
    local value = Json.decode(source)

    truthy(Json.isArray(value.array))
    equal(value.array[1], 1)
    equal(value.array[2], -2.5)
    equal(value.array[3], 602)
    equal(value.text, "snowman: \226\152\131")
    equal(
      Json.encode(value),
      '{"array":[1,-2.5,602],"text":"snowman: '
        .. "\226\152\131"
        .. '"}'
    )
  end)

  test("Json decodes Unicode surrogate pairs", function()
    local value = Json.decode('"\\ud83d\\ude80"')
    equal(value, "\240\159\154\128")
  end)

  test("Json rejects malformed and ambiguous input", function()
    raises(function() Json.decode('{"a":1,"a":2}') end, "duplicate")
    raises(function() Json.decode("[1,]") end, "unexpected token")
    raises(function() Json.decode("01") end, "leading zero")
    raises(function() Json.decode('"\\ud800"') end, "missing its pair")
    raises(function() Json.decode("true false") end, "trailing")
  end)

  test("Json rejects unsupported encoder values", function()
    raises(function() Json.encode(0 / 0) end, "non%-finite")
    raises(function() Json.encode(function() end) end, "function")

    local cyclic = {}
    cyclic.self = cyclic
    raises(function() Json.encode(cyclic) end, "cyclic")
  end)
end
