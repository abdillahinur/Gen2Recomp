package.path = "./?.lua;./?/init.lua;" .. package.path

local tests = {}

local function test(name, fn)
  tests[#tests + 1] = { name = name, fn = fn }
end

local function equal(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ")
      .. ": expected " .. tostring(expected)
      .. ", got " .. tostring(actual), 2)
  end
end

local function truthy(value, message)
  if not value then
    error(message or "expected a truthy value", 2)
  end
end

local function raises(fn, pattern)
  local ok, err = pcall(fn)
  if ok then
    error("expected function to raise an error", 2)
  end
  if pattern and not tostring(err):match(pattern) then
    error(("error did not match %q: %s"):format(pattern, tostring(err)), 2)
  end
end

test("FixedStep runs deterministic steps", function()
  local FixedStep = require("src.core.FixedStep")
  local clock = FixedStep.new({ hz = 60, maxSteps = 8 })
  local calls = 0
  local total = 0

  local steps, alpha = clock:update(1 / 30, function(dt)
    calls = calls + 1
    total = total + dt
  end)

  equal(steps, 2)
  equal(calls, 2)
  truthy(math.abs(total - 1 / 30) < 1e-9)
  truthy(alpha >= 0 and alpha < 1)
end)

test("FixedStep clamps long frames", function()
  local FixedStep = require("src.core.FixedStep")
  local clock = FixedStep.new({ hz = 60, maxSteps = 3 })
  local calls = 0

  local steps = clock:update(10, function()
    calls = calls + 1
  end)

  equal(steps, 3)
  equal(calls, 3)
end)

test("Input edges last for one logic step", function()
  local Input = require("src.core.Input")
  local input = Input.new()

  input:keypressed("z", false)
  truthy(input:down("confirm"))
  input:beginStep()
  truthy(input:wasPressed("confirm"))
  input:endStep()
  truthy(not input:wasPressed("confirm"))
  truthy(input:down("confirm"))

  input:keyreleased("z")
  input:beginStep()
  truthy(input:wasReleased("confirm"))
  truthy(not input:down("confirm"))
end)

test("StateStack applies lifecycle and top-only updates", function()
  local StateStack = require("src.core.StateStack")
  local stack = StateStack.new()
  local events = {}

  local function state(name)
    return {
      enter = function() events[#events + 1] = name .. ":enter" end,
      pause = function() events[#events + 1] = name .. ":pause" end,
      resume = function() events[#events + 1] = name .. ":resume" end,
      exit = function() events[#events + 1] = name .. ":exit" end,
      update = function() events[#events + 1] = name .. ":update" end,
    }
  end

  local first = state("first")
  local second = state("second")
  stack:push(first)
  stack:push(second)
  stack:update()
  equal(stack:size(), 2)
  equal(stack:current(), second)
  stack:pop()
  stack:update()

  equal(table.concat(events, ","),
    "first:enter,first:pause,second:enter,second:update,"
      .. "second:exit,first:resume,first:update")
end)

test("Crystal profiles are found by distinct ids and hashes", function()
  local Profiles = require("src.import.Profiles")
  local version10 = Profiles.get("crystal_us_10")
  local version10ByHash = Profiles.identifySha1(
    "F4CD194BDEE0D04CA4EAC29E09B8E4E9D818C133")
  local version11 = Profiles.get("crystal_us_11")
  local version11ByHash = Profiles.identifySha1(
    "F2F52230B536214EF7C9924F483392993E226CFB")

  equal(#Profiles.all(), 2)
  equal(version10ByHash, version10)
  equal(version11ByHash, version11)
  truthy(version10 ~= version11)
  equal(version10.expectedSize, 2097152)
  equal(version11.expectedSize, 2097152)
  equal(version10.expectedHeader.version, 0)
  equal(version11.expectedHeader.version, 1)
  equal(version11.expectedHeader.title, "PM_CRYSTAL")
  equal(version11.expectedHeader.cartridgeType, 0x10)
  equal(version11.symbols.BaseData.offset, 0x051424)
  equal(version11.symbols.Font.offset, 0x0f8200)
  equal(version11.symbols.JohtoGrassWildMons.offset, 0x02a5e9)
  equal(version11.symbols.JohtoWaterWildMons.offset, 0x02b11d)
  equal(version11.symbols.TrainerGroups.offset, 0x039999)
  equal(version11.battle.moves.bank, 0x10)
  equal(version11.battle.moves.address, 0x5afb)
  equal(version11.battle.moveNames.bank, 0x72)
  equal(version11.schemas.battle, 1)
  equal(#version11.reference.sourceCommit, 40)
  for name, symbol in pairs(version10.symbols) do
    truthy(version11.symbols[name], "v1.1 is missing symbol " .. name)
    equal(version11.symbols[name].offset, symbol.offset)
  end
  truthy(
    version10.reference.symbolsSha256
      ~= version11.reference.symbolsSha256
  )
  truthy(version11.features.realTimeClock)
end)

require("tests.rom_tests")(test, equal, truthy, raises)
require("tests.sha1_tests")(test, equal, truthy, raises)
require("tests.cartridge_header_tests")(test, equal, truthy, raises)
require("tests.rom_identifier_tests")(test, equal, truthy, raises)
require("tests.cache_manifest_tests")(test, equal, truthy, raises)
require("tests.json_tests")(test, equal, truthy, raises)
require("tests.cache_manifest_codec_tests")(test, equal, truthy, raises)
require("tests.cache_store_tests")(test, equal, truthy, raises)
require("tests.cancellation_token_tests")(test, equal, truthy, raises)
require("tests.cache_recovery_tests")(test, equal, truthy, raises)
require("tests.tile_decoder_tests")(test, equal, truthy, raises)
require("tests.cgb_palette_tests")(test, equal, truthy, raises)
require("tests.logical_canvas_tests")(test, equal, truthy, raises)
require("tests.map_grid_tests")(test, equal, truthy, raises)
require("tests.collision_tests")(test, equal, truthy, raises)
require("tests.time_of_day_tests")(test, equal, truthy, raises)
require("tests.encounter_table_tests")(test, equal, truthy, raises)
require("tests.encounter_controller_tests")(test, equal, truthy, raises)
require("tests.trainer_controller_tests")(test, equal, truthy, raises)
require("tests.world_tests")(test, equal, truthy, raises)
require("tests.overworld_sprite_animator_tests")(
  test, equal, truthy)
require("tests.script_definition_tests")(test, equal, truthy, raises)
require("tests.script_runner_tests")(test, equal, truthy, raises)
require("tests.script_state_command_tests")(test, equal, truthy, raises)
require("tests.actor_command_tests")(test, equal, truthy, raises)
require("tests.gameplay_command_tests")(test, equal, truthy, raises)
require("tests.progression_service_tests")(
  test, equal, truthy, raises)
require("tests.pokemon_record_tests")(test, equal, truthy, raises)
require("tests.pokemon_instance_tests")(test, equal, truthy, raises)
require("tests.dv_tests")(test, equal, truthy, raises)
require("tests.battle_state_tests")(test, equal, truthy, raises)
require("tests.battle_action_tests")(test, equal, truthy, raises)
require("tests.damage_tests")(test, equal, truthy, raises)
require("tests.status_tests")(test, equal, truthy, raises)
require("tests.effect_registry_tests")(test, equal, truthy, raises)
require("tests.trainer_ai_tests")(test, equal, truthy, raises)
require("tests.progression_battle_tests")(test, equal, truthy, raises)
require("tests.battle_session_tests")(test, equal, truthy, raises)
require("tests.battle_presentation_tests")(test, equal, truthy, raises)
require("tests.field_menu_presentation_tests")(
  test, equal, truthy, raises)
require("tests.battle_bridge_tests")(test, equal, truthy, raises)
require("tests.crystal_introduction_script_tests")(
  test, equal, truthy, raises)
require("tests.crystal_map_script_tests")(
  test, equal, truthy, raises)
require("tests.crystal_violet_route_script_tests")(
  test, equal, truthy, raises)
require("tests.violet_gym_script_tests")(
  test, equal, truthy, raises)
require("tests.vertical_slice_acceptance_tests")(
  test, equal, truthy, raises)
require("tests.script_coverage_tests")(test, equal, truthy, raises)
require("tests.profile_flow_tests")(test, equal, truthy, raises)
require("tests.game_session_tests")(test, equal, truthy, raises)
require("tests.native_save_tests")(test, equal, truthy, raises)
require("tests.audio_runtime_tests")(test, equal, truthy, raises)
require("tests.game_boy_apu_tests")(test, equal, truthy, raises)
require("tests.crystal_sound_synth_tests")(
  test, equal, truthy, raises)
require("tests.facility_service_tests")(test, equal, truthy, raises)
require("tests.facility_presentation_tests")(
  test, equal, truthy, raises)
require("tests.presentation_controller_tests")(test, equal, truthy, raises)
require("tests.map_presentation_runtime_tests")(test, equal, truthy, raises)
require("tests.charmap_tests")(test, equal, truthy, raises)
require("tests.crystal_text_data_tests")(test, equal, truthy, raises)
require("tests.crystal_font_tests")(test, equal, truthy, raises)
require("tests.crystal_species_tests")(test, equal, truthy, raises)
require("tests.crystal_battle_data_tests")(test, equal, truthy, raises)
require("tests.battle_scene_presentation_tests")(
  test, equal, truthy, raises)
require("tests.crystal_lz_tests")(test, equal, truthy, raises)
require("tests.crystal_tileset_tests")(test, equal, truthy, raises)
require("tests.crystal_encounter_data_tests")(
  test, equal, truthy, raises)
require("tests.crystal_trainer_data_tests")(
  test, equal, truthy, raises)
require("tests.crystal_world_manifest_tests")(
  test, equal, truthy, raises)
require("tests.raw_retention_audit_tests")(test, equal, truthy, raises)
require("tests.crystal_importer_tests")(test, equal, truthy, raises)

local failures = 0

for _, item in ipairs(tests) do
  local ok, err = pcall(item.fn)
  if ok then
    io.write("ok - ", item.name, "\n")
  else
    failures = failures + 1
    io.write("not ok - ", item.name, "\n", tostring(err), "\n")
  end
end

io.write(("\n%d tests, %d failures\n"):format(#tests, failures))
os.exit(failures == 0 and 0 or 1)
