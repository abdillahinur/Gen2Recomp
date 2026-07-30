return function(test, equal, truthy, raises)
  local Sha1 = require("src.import.Sha1")

  test("Sha1 matches standard short vectors", function()
    equal(Sha1.hex(""), "da39a3ee5e6b4b0d3255bfef95601890afd80709")
    equal(Sha1.hex("abc"), "a9993e364706816aba3e25717850c26c9cd0d89d")
    equal(
      Sha1.hex("The quick brown fox jumps over the lazy dog"),
      "2fd4e1c67a2d28fced849ee1bb76e7391b93eb12"
    )
  end)

  test("Sha1 handles block boundaries", function()
    equal(
      Sha1.hex(string.rep("a", 64)),
      "0098ba824b5c16427bd7a1122a5a442a25ec644d"
    )
    equal(
      Sha1.hex(string.rep("a", 65)),
      "11655326c708d70319be2610e8a57d9a5b959d3b"
    )
  end)

  test("Sha1 incremental updates match one-shot hashing", function()
    local chunks = {
      "The quick ",
      "brown fox ",
      "jumps over ",
      "the lazy dog",
    }
    local digest = Sha1.new()
    for _, chunk in ipairs(chunks) do
      equal(digest:update(chunk), digest)
    end
    equal(
      digest:finalHex(),
      Sha1.hex(table.concat(chunks))
    )
  end)

  test("Sha1 hashes arbitrary binary bytes", function()
    local bytes = {}
    for value = 0, 255 do
      bytes[#bytes + 1] = string.char(value)
    end
    equal(
      Sha1.hex(table.concat(bytes)),
      "4916d6bdb7f78e6803698cab32d1586ea457dfc8"
    )
  end)

  test("Sha1 finalization is stable and prevents further updates", function()
    local digest = Sha1.new():update("abc")
    local raw = digest:final()

    equal(#raw, 20)
    equal(digest:final(), raw)
    equal(digest:finalHex(), "a9993e364706816aba3e25717850c26c9cd0d89d")
    raises(function() digest:update("more") end, "finalized")
  end)

  test("Sha1 rejects non-string chunks", function()
    local digest = Sha1.new()
    raises(function() digest:update(nil) end, "binary string")
    raises(function() digest:update(123) end, "binary string")
    truthy(not digest.finalized)
  end)
end

