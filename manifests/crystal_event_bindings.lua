-- Explicit bindings from normalized ROM event indices to hand-written Lua
-- behavior IDs. These contain no ROM pointers, bytecode, or dialogue text.
local function map(definition, objects, bgEvents, coordEvents)
  return {
    definition = definition,
    objects = objects or {},
    bgEvents = bgEvents or {},
    coordEvents = coordEvents or {},
  }
end

return {
  schema = 1,
  maps = {
    ["24:4"] = map("crystal.maps.new_bark_town", {
      "crystal.new_bark.object.teacher",
      "crystal.new_bark.object.fisher",
      "crystal.new_bark.object.rival",
    }, {
      "crystal.new_bark.bg.town_sign",
      "crystal.new_bark.bg.player_house_sign",
      "crystal.new_bark.bg.elm_lab_sign",
      "crystal.new_bark.bg.elm_house_sign",
    }, {
      "crystal.new_bark.coord.teacher_north",
      "crystal.new_bark.coord.teacher_south",
    }),
    ["24:5"] = map("crystal.maps.elms_lab", {
      "crystal.elms_lab.object.elm",
      "crystal.elms_lab.object.aide",
      "crystal.elms_lab.object.cyndaquil_ball",
      "crystal.elms_lab.object.totodile_ball",
      "crystal.elms_lab.object.chikorita_ball",
    }, {
      "crystal.elms_lab.bg.healing_machine",
      "crystal.elms_lab.bg.bookshelf_top_1",
      "crystal.elms_lab.bg.bookshelf_top_2",
      "crystal.elms_lab.bg.bookshelf_top_3",
      "crystal.elms_lab.bg.bookshelf_top_4",
      "crystal.elms_lab.bg.travel_tip_1",
      "crystal.elms_lab.bg.travel_tip_2",
      "crystal.elms_lab.bg.travel_tip_3",
      "crystal.elms_lab.bg.travel_tip_4",
      "crystal.elms_lab.bg.bookshelf_bottom_1",
      "crystal.elms_lab.bg.bookshelf_bottom_2",
      "crystal.elms_lab.bg.bookshelf_bottom_3",
      "crystal.elms_lab.bg.bookshelf_bottom_4",
      "crystal.elms_lab.bg.trashcan",
      "crystal.elms_lab.bg.window",
      "crystal.elms_lab.bg.pc",
    }, {
      "crystal.elms_lab.coord.cant_leave_left",
      "crystal.elms_lab.coord.cant_leave_right",
      "crystal.elms_lab.coord.aide_potion_left",
      "crystal.elms_lab.coord.aide_potion_right",
    }),
    ["24:3"] = map("crystal.maps.route_29", {
      "crystal.route_29.object.tutorial_dude",
      "crystal.route_29.object.youngster",
      "crystal.route_29.object.teacher",
      "crystal.route_29.object.fruit_tree",
      "crystal.route_29.object.fisher",
      "crystal.route_29.object.cooltrainer",
      "crystal.route_29.object.tuscany",
      "crystal.route_29.object.potion",
    }, {
      "crystal.route_29.bg.sign_east",
      "crystal.route_29.bg.sign_west",
    }, {
      "crystal.route_29.coord.tutorial_north",
      "crystal.route_29.coord.tutorial_south",
    }),
    ["24:13"] = map("crystal.maps.route_29_route_46_gate", {
      "crystal.route_29_gate.object.event_1",
      "crystal.route_29_gate.object.event_2",
    }),
    ["26:3"] = map("crystal.maps.cherrygrove_city", {
      "crystal.cherrygrove.object.guide",
      "crystal.cherrygrove.object.rival",
      "crystal.cherrygrove.object.teacher",
      "crystal.cherrygrove.object.youngster",
      "crystal.cherrygrove.object.fisher",
    }, {
      "crystal.cherrygrove.bg.city_sign",
      "crystal.cherrygrove.bg.guide_house_sign",
      "crystal.cherrygrove.bg.mart_sign",
      "crystal.cherrygrove.bg.pokecenter_sign",
    }, {
      "crystal.cherrygrove.coord.rival_north",
      "crystal.cherrygrove.coord.rival_south",
    }),
    ["26:6"] = map("crystal.maps.cherrygrove_gym_speech_house", {
      "crystal.cherrygrove_gym_house.object.event_1",
      "crystal.cherrygrove_gym_house.object.event_2",
    }, {
      "crystal.cherrygrove_gym_house.bg.event_1",
      "crystal.cherrygrove_gym_house.bg.event_2",
    }),
    ["26:7"] = map("crystal.maps.guide_gents_house", {
      "crystal.guide_house.object.event_1",
    }, {
      "crystal.guide_house.bg.event_1",
      "crystal.guide_house.bg.event_2",
    }),
    ["26:8"] = map("crystal.maps.cherrygrove_evolution_speech_house", {
      "crystal.cherrygrove_evolution_house.object.event_1",
      "crystal.cherrygrove_evolution_house.object.event_2",
    }, {
      "crystal.cherrygrove_evolution_house.bg.event_1",
      "crystal.cherrygrove_evolution_house.bg.event_2",
    }),
    ["26:9"] = map("crystal.maps.route_30_berry_house", {
      "crystal.route_30_berry_house.object.event_1",
    }, {
      "crystal.route_30_berry_house.bg.event_1",
      "crystal.route_30_berry_house.bg.event_2",
    }),
    ["26:10"] = map("crystal.maps.mr_pokemons_house", {
      "crystal.mr_pokemon.object.mr_pokemon",
      "crystal.mr_pokemon.object.oak",
    }, {
      "crystal.mr_pokemon.bg.bookshelf_left",
      "crystal.mr_pokemon.bg.bookshelf_right",
      "crystal.mr_pokemon.bg.magazines_left",
      "crystal.mr_pokemon.bg.magazines_right",
      "crystal.mr_pokemon.bg.computer",
    }),
    ["26:11"] = map("crystal.maps.route_31_violet_gate", {
      "crystal.route_31_gate.object.event_1",
      "crystal.route_31_gate.object.event_2",
    }),
    ["26:1"] = map("crystal.maps.route_30", {
      "crystal.route_30.object.youngster",
      "crystal.route_30.object.joey",
      "crystal.route_30.object.mikey",
      "crystal.route_30.object.don",
      "crystal.route_30.object.battle_youngster",
      "crystal.route_30.object.battle_mon_1",
      "crystal.route_30.object.battle_mon_2",
      "crystal.route_30.object.fruit_tree_1",
      "crystal.route_30.object.fruit_tree_2",
      "crystal.route_30.object.cooltrainer",
      "crystal.route_30.object.antidote",
    }, {
      "crystal.route_30.bg.sign",
      "crystal.route_30.bg.mr_pokemon_directions",
      "crystal.route_30.bg.mr_pokemon_house",
      "crystal.route_30.bg.trainer_tips",
      "crystal.route_30.bg.hidden_potion",
    }),
    ["26:2"] = map("crystal.maps.route_31", {
      "crystal.route_31.object.mail_recipient",
      "crystal.route_31.object.youngster",
      "crystal.route_31.object.wade",
      "crystal.route_31.object.cooltrainer",
      "crystal.route_31.object.fruit_tree",
      "crystal.route_31.object.potion",
      "crystal.route_31.object.poke_ball",
    }, {
      "crystal.route_31.bg.route_sign",
      "crystal.route_31.bg.dark_cave_sign",
    }),
    ["10:1"] = map("crystal.maps.route_32", {
      "crystal.route_32.object.justin",
      "crystal.route_32.object.ralph",
      "crystal.route_32.object.henry",
      "crystal.route_32.object.albert",
      "crystal.route_32.object.gordon",
      "crystal.route_32.object.roland",
      "crystal.route_32.object.liz",
      "crystal.route_32.object.badge_guard",
      "crystal.route_32.object.peter",
      "crystal.route_32.object.slowpoke_tail",
      "crystal.route_32.object.great_ball",
      "crystal.route_32.object.roar_gift",
      "crystal.route_32.object.frieda",
      "crystal.route_32.object.repel",
    }, {
      "crystal.route_32.bg.route_sign",
      "crystal.route_32.bg.ruins_sign",
      "crystal.route_32.bg.union_cave_sign",
      "crystal.route_32.bg.pokecenter_sign",
      "crystal.route_32.bg.hidden_great_ball",
      "crystal.route_32.bg.hidden_super_potion",
    }, {
      "crystal.route_32.coord.badge_guard",
      "crystal.route_32.coord.slowpoke_tail",
    }),
    ["10:3"] = map("crystal.maps.route_36", {
      "crystal.route_36.object.mark",
      "crystal.route_36.object.alan",
      "crystal.route_36.object.sudowoodo",
      "crystal.route_36.object.lass",
      "crystal.route_36.object.rock_smash_guy",
      "crystal.route_36.object.fruit_tree",
      "crystal.route_36.object.arthur",
      "crystal.route_36.object.floria",
      "crystal.route_36.object.suicune",
    }, {
      "crystal.route_36.bg.trainer_tips_stats",
      "crystal.route_36.bg.ruins_sign",
      "crystal.route_36.bg.route_sign",
      "crystal.route_36.bg.trainer_tips_dig",
    }, {
      "crystal.route_36.coord.suicune_left",
      "crystal.route_36.coord.suicune_right",
    }),
    ["10:5"] = map("crystal.maps.violet_city", {
      "crystal.violet.object.earl",
      "crystal.violet.object.lass",
      "crystal.violet.object.super_nerd",
      "crystal.violet.object.gramps",
      "crystal.violet.object.youngster",
      "crystal.violet.object.fruit_tree",
      "crystal.violet.object.pp_up",
      "crystal.violet.object.rare_candy",
    }, {
      "crystal.violet.bg.city_sign",
      "crystal.violet.bg.gym_sign",
      "crystal.violet.bg.sprout_tower_sign",
      "crystal.violet.bg.academy_sign",
      "crystal.violet.bg.pokecenter_sign",
      "crystal.violet.bg.mart_sign",
      "crystal.violet.bg.hidden_hyper_potion",
    }),
    ["10:7"] = map("crystal.maps.violet_gym", {
      "crystal.violet_gym.object.falkner",
      "crystal.violet_gym.object.rod",
      "crystal.violet_gym.object.abe",
      "crystal.violet_gym.object.guide",
    }, {
      "crystal.violet_gym.bg.statue_left",
      "crystal.violet_gym.bg.statue_right",
    }),
    ["10:8"] = map("crystal.maps.earls_pokemon_academy", {
      "crystal.earls_academy.object.event_1",
      "crystal.earls_academy.object.event_2",
      "crystal.earls_academy.object.event_3",
      "crystal.earls_academy.object.event_4",
      "crystal.earls_academy.object.event_5",
      "crystal.earls_academy.object.event_6",
    }, {
      "crystal.earls_academy.bg.event_1",
      "crystal.earls_academy.bg.event_2",
      "crystal.earls_academy.bg.event_3",
      "crystal.earls_academy.bg.event_4",
    }),
    ["10:9"] = map("crystal.maps.violet_nickname_speech_house", {
      "crystal.violet_nickname_house.object.event_1",
      "crystal.violet_nickname_house.object.event_2",
      "crystal.violet_nickname_house.object.event_3",
    }),
    ["10:11"] = map("crystal.maps.violet_kyles_house", {
      "crystal.violet_kyle_house.object.event_1",
      "crystal.violet_kyle_house.object.event_2",
    }),
  },
  -- Imported and reachable, but no hand-written behavior yet. Declaring them
  -- keeps the loader fail-closed: an imported map that is neither bound nor
  -- listed here is a startup error instead of a silent no-op at the A button.
  -- Facility counters on these maps still work; they are served by the
  -- sprite-matched staff path in WorldState, not by event bindings.
  unimplemented = {
    ["24:1"] = "route_26 object and sign dialogue not yet authored",
    ["24:2"] = "route_27 object and sign dialogue not yet authored",
    ["24:6"] = "players_house_1f dialogue not yet authored",
    ["24:7"] = "players_house_2f dialogue not yet authored",
    ["24:8"] = "players_neighbors_house dialogue not yet authored",
    ["24:9"] = "elms_house dialogue not yet authored",
    ["24:10"] = "route_26_heal_house dialogue not yet authored",
    ["24:11"] = "day_of_week_siblings_house dialogue not yet authored",
    ["24:12"] = "route_27_sandstorm_house dialogue not yet authored",
    ["26:4"] = "cherrygrove_mart shelf and customer dialogue not authored",
    ["26:5"] = "cherrygrove_pokecenter_1f trainer dialogue not authored",
    ["10:2"] = "route_35 object and sign dialogue not yet authored",
    ["10:4"] = "route_37 object and sign dialogue not yet authored",
    ["10:6"] = "violet_mart shelf and customer dialogue not authored",
    ["10:10"] = "violet_pokecenter_1f trainer dialogue not authored",
    ["10:12"] = "route_32_ruins_of_alph_gate dialogue not yet authored",
    ["10:13"] = "route_32_pokecenter_1f trainer dialogue not authored",
    ["10:14"] = "route_35_goldenrod_gate dialogue not yet authored",
    ["10:15"] = "route_35_national_park_gate dialogue not yet authored",
    ["10:16"] = "route_36_ruins_of_alph_gate dialogue not yet authored",
    ["10:17"] = "route_36_national_park_gate dialogue not yet authored",
  },
}
