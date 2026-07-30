return function(test, equal, truthy, raises)
  local CrystalTextData = require("src.import.CrystalTextData")
  local DialogueService = require("src.script.DialogueService")
  local PresentationController =
    require("src.ui.PresentationController")
  local Rom = require("src.import.Rom")
  local RomTextProvider = require("src.ui.RomTextProvider")

  local function fixture()
    local encoded = string.char(
      0x00,
      0x87, 0xa4, 0xab, 0xab, 0xae,
      0x4f,
      0x52,
      0x51,
      0x50,
      0x01, 0x34, 0x12,
      0x00, 0xe7, 0x57
    )
    local offset = 10
    local rom = Rom.new(string.rep("\0", offset) .. encoded)
    local profile = {
      id = "test_crystal",
      symbols = {
        SyntheticText = { offset = offset },
      },
      text = {
        schema = 1,
        aliases = {
          ["test.choice.synthetic"] = "test.text.synthetic",
        },
        entries = {
          ["test.text.synthetic"] = {
            symbol = "SyntheticText",
            ramKeys = { "species" },
          },
        },
      },
    }
    return rom, profile
  end

  test("Crystal text data decodes commands without retaining ROM bytes",
    function()
      local rom, profile = fixture()
      local catalog = CrystalTextData.extract(rom, profile)
      equal(catalog.schema, 1)
      equal(catalog.profileId, "test_crystal")
      equal(catalog.count, 1)
      local entry = catalog.entries["test.text.synthetic"]
      equal(entry.terminal, "done")
      equal(entry.byteLength, 16)
      equal(entry.tokens[1].kind, "text")
      equal(entry.tokens[1].value, "Hello")
      equal(entry.tokens[2].kind, "line")
      equal(entry.tokens[3].kind, "substitution")
      equal(entry.tokens[3].value, "player")
      equal(entry.tokens[4].kind, "paragraph")
      equal(entry.tokens[5].kind, "substitution")
      equal(entry.tokens[5].value, "species")
      equal(entry.tokens[6].value, "!")
    end)

  test("ROM text provider paginates and substitutes semantic values",
    function()
      local rom, profile = fixture()
      local provider = RomTextProvider.new(
        CrystalTextData.extract(rom, profile),
        { values = { player = "NOVA" } }
      )
      local pages = provider:resolvePages("test.text.synthetic", {
        species = "crystal.species.cyndaquil",
      })
      equal(#pages, 2)
      equal(pages[1], "Hello\nNOVA")
      equal(pages[2], "CYNDAQUIL!")
      equal(
        provider:resolve("test.text.synthetic", {
          species = "crystal.species.cyndaquil",
        }),
        "Hello\nNOVA\n\nCYNDAQUIL!"
      )
      equal(
        provider:resolvePages("test.choice.synthetic", {
          species = "crystal.species.cyndaquil",
        })[1],
        "Hello\nNOVA"
      )
    end)

  test("presentation requires every ROM-owned text page to advance",
    function()
      local rom, profile = fixture()
      local dialogue = DialogueService.new()
      local provider = RomTextProvider.new(
        CrystalTextData.extract(rom, profile),
        { values = { player = "NOVA" } }
      )
      local controller = PresentationController.new(
        { dialogue = dialogue },
        { textProvider = provider }
      )
      dialogue:text({
        id = "test.text.synthetic",
        substitutions = {
          species = "crystal.species.cyndaquil",
        },
      })
      local input = {
        wasPressed = function(_, action) return action == "confirm" end,
      }
      equal(controller:model().pageCount, 2)
      controller:update(input)
      truthy(dialogue.active)
      equal(controller:model().page, 2)
      controller:update(input)
      equal(dialogue.active, nil)
    end)

  test("ROM-owned choice prompts paginate before options", function()
    local rom, profile = fixture()
    local dialogue = DialogueService.new()
    local provider = RomTextProvider.new(
      CrystalTextData.extract(rom, profile),
      { values = { player = "NOVA", species = "TESTMON" } }
    )
    local controller = PresentationController.new(
      { dialogue = dialogue },
      { textProvider = provider }
    )
    dialogue:choice({
      id = "test.choice.synthetic",
      options = {
        { id = "test.option.yes", textId = "common.text.yes" },
        { id = "test.option.no", textId = "common.text.no" },
      },
    })
    local input = {
      wasPressed = function(_, action) return action == "confirm" end,
    }
    equal(controller:model().kind, "text")
    controller:update(input)
    equal(controller:model().kind, "text")
    controller:update(input)
    equal(controller:model().kind, "choice")
    controller:update(input)
    equal(dialogue.active, nil)
  end)

  test("Crystal text data rejects missing symbols and commands", function()
    local rom, profile = fixture()
    profile.symbols.SyntheticText = nil
    raises(function()
      CrystalTextData.extract(rom, profile)
    end, "missing symbol")

    raises(function()
      CrystalTextData.decodeEntry(
        Rom.new(string.char(0x09, 0, 0, 0, 0)),
        0,
        {}
      )
    end, "unsupported command")
  end)
end
