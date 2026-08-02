-- This manifest contains extraction metadata only. The text itself remains
-- exclusively in the player's verified ROM and is decoded at runtime.
return {
  schema = 1,
  aliases = {
    ["crystal.choice.player_gender"] =
      "crystal.text.introduction.gender_prompt",
    ["crystal.choice.elms_lab.take_cyndaquil"] =
      "crystal.text.elms_lab.take_cyndaquil",
    ["crystal.choice.elms_lab.take_totodile"] =
      "crystal.text.elms_lab.take_totodile",
    ["crystal.choice.elms_lab.take_chikorita"] =
      "crystal.text.elms_lab.take_chikorita",
  },
  entries = {
    ["crystal.text.introduction.gender_prompt"] =
      { symbol = "_AreYouABoyOrAreYouAGirlText" },
    ["crystal.text.introduction.clock_woke_up"] =
      { symbol = "_OakTimeWokeUpText" },
    ["crystal.text.introduction.clock_what_time"] =
      { symbol = "_OakTimeWhatTimeIsItText" },
    ["crystal.text.introduction.clock_what_hours"] =
      { symbol = "_OakTimeWhatHoursText" },
    ["crystal.text.introduction.clock_hours_question"] =
      { symbol = "_OakTimeHoursQuestionMarkText" },
    ["crystal.text.introduction.clock_minutes"] =
      { symbol = "_OakTimeHowManyMinutesText" },
    ["crystal.text.introduction.clock_whoa"] =
      { symbol = "_OakTimeWhoaMinutesText" },
    ["crystal.text.introduction.clock_minutes_question"] =
      { symbol = "_OakTimeMinutesQuestionMarkText" },
    ["crystal.text.introduction.clock_morning"] =
      { symbol = "_OakTimeOversleptText" },
    ["crystal.text.introduction.clock_day"] =
      { symbol = "_OakTimeYikesText" },
    ["crystal.text.introduction.clock_night"] =
      { symbol = "_OakTimeSoDarkText" },
    ["crystal.text.introduction.oak_1"] = { symbol = "_OakText1" },
    ["crystal.text.introduction.oak_2"] = { symbol = "_OakText2" },
    ["crystal.text.introduction.oak_3"] = { symbol = "_OakText3" },
    ["crystal.text.introduction.oak_4"] = { symbol = "_OakText4" },
    ["crystal.text.introduction.oak_5"] = { symbol = "_OakText5" },
    ["crystal.text.introduction.oak_6"] = { symbol = "_OakText6" },
    ["crystal.text.introduction.oak_7"] = { symbol = "_OakText7" },

    ["crystal.text.new_bark.gear_is_impressive"] =
      { symbol = "Text_GearIsImpressive" },
    ["crystal.text.new_bark.wait"] = { symbol = "Text_WaitPlayer" },
    ["crystal.text.new_bark.what_are_you_doing"] =
      { symbol = "Text_WhatDoYouThinkYoureDoing" },
    ["crystal.text.new_bark.dangerous_without_pokemon"] =
      { symbol = "Text_ItsDangerousToGoAlone" },
    ["crystal.text.new_bark.pokemon_is_adorable"] =
      { symbol = "Text_YourMonIsAdorable" },
    ["crystal.text.new_bark.tell_mom_before_leaving"] =
      { symbol = "Text_TellMomIfLeaving" },
    ["crystal.text.new_bark.call_mom"] =
      { symbol = "Text_CallMomOnGear" },
    ["crystal.text.new_bark.elm_discovered_pokemon"] =
      { symbol = "Text_ElmDiscoveredNewMon" },
    ["crystal.text.new_bark.rival_observes_lab"] =
      { symbol = "NewBarkTownRivalText1" },
    ["crystal.text.new_bark.rival_confronts_player"] =
      { symbol = "NewBarkTownRivalText2" },
    ["crystal.text.new_bark.town_sign"] =
      { symbol = "NewBarkTownSignText" },
    ["crystal.text.new_bark.player_house_sign"] =
      { symbol = "NewBarkTownPlayersHouseSignText" },
    ["crystal.text.new_bark.elm_lab_sign"] =
      { symbol = "NewBarkTownElmsLabSignText" },
    ["crystal.text.new_bark.elm_house_sign"] =
      { symbol = "NewBarkTownElmsHouseSignText" },

    ["crystal.text.elms_lab.elm_intro"] = { symbol = "ElmText_Intro" },
    ["crystal.text.elms_lab.elm_accepted"] =
      { symbol = "ElmText_Accepted" },
    ["crystal.text.elms_lab.elm_refused"] =
      { symbol = "ElmText_Refused" },
    ["crystal.text.elms_lab.research_ambitions"] =
      { symbol = "ElmText_ResearchAmbitions" },
    ["crystal.text.elms_lab.got_email"] =
      { symbol = "ElmText_GotAnEmail" },
    ["crystal.text.elms_lab.mr_pokemon_mission"] =
      { symbol = "ElmText_MissionFromMrPokemon" },
    ["crystal.text.elms_lab.choose_pokemon"] =
      { symbol = "ElmText_ChooseAPokemon" },
    ["crystal.text.elms_lab.let_your_pokemon_battle"] =
      { symbol = "ElmText_LetYourMonBattleIt" },
    ["crystal.text.elms_lab.where_are_you_going"] =
      { symbol = "LabWhereGoingText" },
    ["crystal.text.elms_lab.take_cyndaquil"] =
      { symbol = "TakeCyndaquilText" },
    ["crystal.text.elms_lab.take_totodile"] =
      { symbol = "TakeTotodileText" },
    ["crystal.text.elms_lab.take_chikorita"] =
      { symbol = "TakeChikoritaText" },
    ["crystal.text.elms_lab.did_not_choose_starter"] =
      { symbol = "DidntChooseStarterText" },
    ["crystal.text.elms_lab.chose_starter"] =
      { symbol = "ChoseStarterText" },
    ["crystal.text.elms_lab.received_starter"] = {
      symbol = "ReceivedStarterText",
      ramKeys = { "species" },
    },
    ["crystal.text.elms_lab.directions_to_mr_pokemon"] =
      { symbol = "ElmDirectionsText1" },
    ["crystal.text.elms_lab.healing_machine_directions"] =
      { symbol = "ElmDirectionsText2" },
    ["crystal.text.elms_lab.elm_is_counting_on_you"] =
      { symbol = "ElmDirectionsText3" },
    ["crystal.text.elms_lab.got_elm_phone_number"] =
      { symbol = "GotElmsNumberText" },
    ["crystal.text.elms_lab.elm_describes_mr_pokemon"] =
      { symbol = "ElmDescribesMrPokemonText" },
    ["crystal.text.elms_lab.poke_ball"] =
      { symbol = "ElmPokeBallText" },
    ["crystal.text.elms_lab.healing_machine_unknown"] =
      { symbol = "ElmsLabHealingMachineText1" },
    ["crystal.text.elms_lab.healing_machine_ready"] =
      { symbol = "ElmsLabHealingMachineText2" },
    ["crystal.text.elms_lab.aide_gives_potion"] =
      { symbol = "AideText_GiveYouPotion" },
    ["crystal.text.elms_lab.aide_always_busy"] =
      { symbol = "AideText_AlwaysBusy" },
    ["crystal.text.elms_lab.window_normal"] =
      { symbol = "ElmsLabWindowText1" },
    ["crystal.text.elms_lab.window_break_in"] =
      { symbol = "ElmsLabWindowText2" },
    ["crystal.text.elms_lab.travel_tip_1"] =
      { symbol = "ElmsLabTravelTip1Text" },
    ["crystal.text.elms_lab.travel_tip_2"] =
      { symbol = "ElmsLabTravelTip2Text" },
    ["crystal.text.elms_lab.travel_tip_3"] =
      { symbol = "ElmsLabTravelTip3Text" },
    ["crystal.text.elms_lab.travel_tip_4"] =
      { symbol = "ElmsLabTravelTip4Text" },
    ["crystal.text.elms_lab.trashcan"] =
      { symbol = "ElmsLabTrashcanText" },
    ["crystal.text.elms_lab.pc"] = { symbol = "ElmsLabPCText" },
    ["crystal.text.elms_lab.officer_intro"] =
      { symbol = "ElmsLabOfficerText1" },
    ["crystal.text.elms_lab.officer_named_rival"] =
      { symbol = "ElmsLabOfficerText2" },
    ["crystal.text.common.difficult_bookshelf"] =
      { symbol = "DifficultBookshelfText" },

    ["crystal.text.cherrygrove.guide_intro"] =
      { symbol = "GuideGentIntroText" },
    ["crystal.text.cherrygrove.guide_tour"] =
      { symbol = "GuideGentTourText1" },
    ["crystal.text.cherrygrove.guide_pokecenter"] =
      { symbol = "GuideGentPokecenterText" },
    ["crystal.text.cherrygrove.guide_mart"] =
      { symbol = "GuideGentMartText" },
    ["crystal.text.cherrygrove.guide_route_30"] =
      { symbol = "GuideGentRoute30Text" },
    ["crystal.text.cherrygrove.guide_sea"] =
      { symbol = "GuideGentSeaText" },
    ["crystal.text.cherrygrove.guide_gift"] =
      { symbol = "GuideGentGiftText" },
    ["crystal.text.cherrygrove.got_map_card"] =
      { symbol = "GotMapCardText" },
    ["crystal.text.cherrygrove.guide_pokegear"] =
      { symbol = "GuideGentPokegearText" },
    ["crystal.text.cherrygrove.guide_no"] =
      { symbol = "GuideGentNoText" },
    ["crystal.text.cherrygrove.rival_seen"] =
      { symbol = "CherrygroveRivalText_Seen" },
    ["crystal.text.cherrygrove.rival_won"] =
      { symbol = "CherrygroveRivalText_YouWon" },
    ["crystal.text.cherrygrove.rival_lost"] =
      { symbol = "CherrygroveRivalText_YouLost" },

    ["crystal.text.mr_pokemon.intro_1"] =
      { symbol = "MrPokemonIntroText1" },
    ["crystal.text.mr_pokemon.intro_2"] =
      { symbol = "MrPokemonIntroText2" },
    ["crystal.text.mr_pokemon.got_egg"] =
      { symbol = "MrPokemonsHouse_GotEggText" },
    ["crystal.text.mr_pokemon.intro_3"] =
      { symbol = "MrPokemonIntroText3" },
    ["crystal.text.mr_pokemon.intro_4"] =
      { symbol = "MrPokemonIntroText4" },
    ["crystal.text.mr_pokemon.intro_5"] =
      { symbol = "MrPokemonIntroText5" },
    ["crystal.text.mr_pokemon.heal"] =
      { symbol = "MrPokemonsHouse_MrPokemonHealText" },
    ["crystal.text.mr_pokemon.depending_on_you"] =
      { symbol = "MrPokemonText_ImDependingOnYou" },
    ["crystal.text.mr_pokemon.oak_1"] =
      { symbol = "MrPokemonsHouse_OakText1" },
    ["crystal.text.mr_pokemon.got_pokedex"] =
      { symbol = "MrPokemonsHouse_GetDexText" },
    ["crystal.text.mr_pokemon.oak_2"] =
      { symbol = "MrPokemonsHouse_OakText2" },

    ["crystal.text.route_30.directions"] =
      { symbol = "Route30YoungsterText_DirectionsToMrPokemonsHouse" },
    ["crystal.text.route_30.everyone_battling"] =
      { symbol = "Route30YoungsterText_EveryoneIsBattling" },
    ["crystal.text.route_30.sign"] =
      { symbol = "Route30SignText" },
    ["crystal.text.route_30.directions_sign"] =
      { symbol = "MrPokemonsHouseDirectionsSignText" },
    ["crystal.text.route_30.mr_pokemon_sign"] =
      { symbol = "MrPokemonsHouseSignText" },
    ["crystal.text.route_30.trainer_tips"] =
      { symbol = "Route30TrainerTipsText" },
    ["crystal.text.route_31.youngster"] =
      { symbol = "Route31YoungsterText" },
    ["crystal.text.route_31.sign"] =
      { symbol = "Route31SignText" },
    ["crystal.text.route_31.dark_cave_sign"] =
      { symbol = "DarkCaveSignText" },

    ["crystal.text.violet.lass"] = { symbol = "VioletCityLassText" },
    ["crystal.text.violet.super_nerd"] =
      { symbol = "VioletCitySuperNerdText" },
    ["crystal.text.violet.gramps"] =
      { symbol = "VioletCityGrampsText" },
    ["crystal.text.violet.youngster"] =
      { symbol = "VioletCityYoungsterText" },
    ["crystal.text.violet.city_sign"] =
      { symbol = "VioletCitySignText" },
    ["crystal.text.violet.gym_sign"] =
      { symbol = "VioletGymSignText" },
    ["crystal.text.violet.sprout_tower_sign"] =
      { symbol = "SproutTowerSignText" },
    ["crystal.text.violet.academy_sign"] =
      { symbol = "EarlsPokemonAcademySignText" },

    ["crystal.text.violet_gym.falkner_intro"] =
      { symbol = "FalknerIntroText" },
    ["crystal.text.violet_gym.falkner_win"] =
      { symbol = "FalknerWinLossText" },
    ["crystal.text.violet_gym.got_zephyr_badge"] =
      { symbol = "ReceivedZephyrBadgeText" },
    ["crystal.text.violet_gym.zephyr_badge"] =
      { symbol = "FalknerZephyrBadgeText" },
    ["crystal.text.violet_gym.tm31"] =
      { symbol = "FalknerTMMudSlapText" },
    ["crystal.text.violet_gym.after"] =
      { symbol = "FalknerFightDoneText" },
    ["crystal.text.violet_gym.rod_seen"] =
      { symbol = "BirdKeeperRodSeenText" },
    ["crystal.text.violet_gym.rod_after"] =
      { symbol = "BirdKeeperRodAfterBattleText" },
    ["crystal.text.violet_gym.abe_seen"] =
      { symbol = "BirdKeeperAbeSeenText" },
    ["crystal.text.violet_gym.abe_after"] =
      { symbol = "BirdKeeperAbeAfterBattleText" },
    ["crystal.text.violet_gym.guide_before"] =
      { symbol = "VioletGymGuideText" },
    ["crystal.text.violet_gym.guide_after"] =
      { symbol = "VioletGymGuideWinText" },

    ["crystal.text.common.fruit_tree_empty"] =
      { symbol = "_NothingHereText" },
    ["crystal.text.common.fruit_tree_picked"] = {
      symbol = "_ObtainedFruitText",
      ramKeys = { "item" },
    },
    ["crystal.text.common.item_received"] = {
      symbol = "_PlayerFoundItemText",
      ramKeys = { "item" },
    },
    ["crystal.text.common.mart_sign"] = { symbol = "MartSignText" },
    ["crystal.text.common.pokecenter_sign"] =
      { symbol = "PokecenterSignText" },

    ["crystal.text.cherrygrove.city_sign"] =
      { symbol = "CherrygroveCitySignText" },
    ["crystal.text.cherrygrove.guide_house_sign"] =
      { symbol = "GuideGentsHouseSignText" },
    ["crystal.text.cherrygrove.teacher_has_map"] =
      { symbol = "CherrygroveTeacherText_HaveMapCard" },
    ["crystal.text.cherrygrove.teacher_needs_map"] =
      { symbol = "CherrygroveTeacherText_NoMapCard" },
    ["crystal.text.cherrygrove.youngster_has_pokedex"] =
      { symbol = "CherrygroveYoungsterText_HavePokedex" },
    ["crystal.text.cherrygrove.youngster_no_pokedex"] =
      { symbol = "CherrygroveYoungsterText_NoPokedex" },
    ["crystal.text.cherrygrove.fisher"] =
      { symbol = "MysticWaterGuyTextBefore" },

    ["crystal.text.cherrygrove_evolution_house.lass"] =
      { symbol = "CherrygroveEvolutionSpeechHouseLassText" },
    ["crystal.text.cherrygrove_evolution_house.youngster"] =
      { symbol = "CherrygroveEvolutionSpeechHouseYoungsterText" },
    ["crystal.text.cherrygrove_gym_house.bug_catcher"] =
      { symbol = "CherrygroveGymSpeechHouseBugCatcherText" },
    ["crystal.text.cherrygrove_gym_house.pokefan"] =
      { symbol = "CherrygroveGymSpeechHousePokefanMText" },
    ["crystal.text.guide_house.guide"] =
      { symbol = "GuideGentsHouseGuideGentText" },

    ["crystal.text.earls_academy.blackboard"] =
      { symbol = "AcademyBlackboardText" },
    ["crystal.text.earls_academy.earl"] =
      { symbol = "AcademyEarlIntroText" },
    ["crystal.text.earls_academy.gameboy_kid_left"] =
      { symbol = "EarlsPokemonAcademyGameboyKid1Text" },
    ["crystal.text.earls_academy.gameboy_kid_right"] =
      { symbol = "EarlsPokemonAcademyGameboyKid2Text" },
    ["crystal.text.earls_academy.notebook"] =
      { symbol = "AcademyNotebookText" },
    ["crystal.text.earls_academy.youngster_berry"] =
      { symbol = "EarlsPokemonAcademyYoungster2Text" },
    ["crystal.text.earls_academy.youngster_notes"] =
      { symbol = "EarlsPokemonAcademyYoungster1Text" },

    ["crystal.text.mr_pokemon.computer"] =
      { symbol = "MrPokemonsHouse_BrokenComputerText" },
    ["crystal.text.mr_pokemon.magazines"] =
      { symbol = "MrPokemonsHouse_ForeignMagazinesText" },

    ["crystal.text.route_29.fisher"] = { symbol = "Route29FisherText" },
    ["crystal.text.route_29.sign"] = { symbol = "Route29Sign1Text" },
    ["crystal.text.route_29.teacher"] = { symbol = "Route29TeacherText" },
    ["crystal.text.route_29.tuscany_after"] =
      { symbol = "TuscanyGaveGiftText" },
    ["crystal.text.route_29.tuscany_gift"] =
      { symbol = "TuscanyGivesGiftText" },
    ["crystal.text.route_29.tuscany_intro"] =
      { symbol = "MeetTuscanyText" },
    ["crystal.text.route_29.tutorial_debrief"] =
      { symbol = "CatchingTutorialDebriefText" },
    ["crystal.text.route_29.tutorial_declined"] =
      { symbol = "CatchingTutorialDeclinedText" },
    ["crystal.text.route_29.tutorial_intro"] =
      { symbol = "CatchingTutorialIntroText" },
    ["crystal.text.route_29.waiting_for_morning"] =
      { symbol = "Route29CooltrainerMText_WaitingForMorning" },
    ["crystal.text.route_29.waiting_for_night"] =
      { symbol = "Route29CooltrainerMText_WaitingForNight" },
    ["crystal.text.route_29.youngster"] =
      { symbol = "Route29YoungsterText" },
    ["crystal.text.route_29_gate.officer"] =
      { symbol = "Route29Route46GateOfficerText" },
    ["crystal.text.route_29_gate.youngster"] =
      { symbol = "Route29Route46GateYoungsterText" },

    ["crystal.text.route_30.battle_mon"] = { symbol = "Text_UseTackle" },
    ["crystal.text.route_30.big_battle"] =
      { symbol = "Text_ThisIsABigBattle" },
    ["crystal.text.route_30.cooltrainer"] =
      { symbol = "Route30CooltrainerFText" },
    ["crystal.text.route_30.don_after"] =
      { symbol = "BugCatcherDonAfterText" },
    ["crystal.text.route_30.joey_after"] =
      { symbol = "YoungsterJoey1AfterText" },
    ["crystal.text.route_30.mikey_after"] =
      { symbol = "YoungsterMikeyAfterText" },
    ["crystal.text.route_30_berry_house.after"] =
      { symbol = "Route30BerrySpeechHouseCheckTreesText" },
    ["crystal.text.route_30_berry_house.gift"] =
      { symbol = "Route30BerrySpeechHouseMonEatBerriesText" },

    ["crystal.text.route_31.cooltrainer"] =
      { symbol = "Route31CooltrainerMText" },
    ["crystal.text.route_31.mail_recipient"] =
      { symbol = "Text_Route31SleepyMan" },
    ["crystal.text.route_31.wade_after"] =
      { symbol = "BugCatcherWade1AfterText" },
    ["crystal.text.route_31_gate.cooltrainer"] =
      { symbol = "Route31VioletGateCooltrainerFText" },
    ["crystal.text.route_31_gate.officer"] =
      { symbol = "Route31VioletGateOfficerText" },

    ["crystal.text.route_32.albert_after"] =
      { symbol = "YoungsterAlbertAfterText" },
    ["crystal.text.route_32.frieda_after"] =
      { symbol = "FriedaGaveGiftText" },
    ["crystal.text.route_32.frieda_intro"] =
      { symbol = "MeetFriedaText" },
    ["crystal.text.route_32.gordon_after"] =
      { symbol = "YoungsterGordonAfterText" },
    ["crystal.text.route_32.guard_after_badge"] =
      { symbol = "Route32CooltrainerMText_ExperiencesShouldBeUseful" },
    ["crystal.text.route_32.guard_before_badge"] =
      { symbol = "Route32CooltrainerMText_WhatsTheHurry" },
    ["crystal.text.route_32.henry_after"] =
      { symbol = "FisherHenryAfterText" },
    ["crystal.text.route_32.justin_after"] =
      { symbol = "FisherJustinAfterText" },
    ["crystal.text.route_32.liz_after"] =
      { symbol = "PicnickerLiz1AfterText" },
    ["crystal.text.route_32.peter_after"] =
      { symbol = "BirdKeeperPeterAfterText" },
    ["crystal.text.route_32.ralph_after"] =
      { symbol = "FisherRalphAfterText" },
    ["crystal.text.route_32.roar_intro"] = { symbol = "Text_RoarIntro" },
    ["crystal.text.route_32.roar_outro"] = { symbol = "Text_RoarOutro" },
    ["crystal.text.route_32.roland_after"] =
      { symbol = "CamperRolandAfterText" },
    ["crystal.text.route_32.route_sign"] =
      { symbol = "Route32SignText" },
    ["crystal.text.route_32.ruins_sign"] =
      { symbol = "Route32RuinsSignText" },
    ["crystal.text.route_32.slowpoke_tail_offer"] =
      { symbol = "Text_MillionDollarSlowpokeTail" },
    ["crystal.text.route_32.slowpoke_tail_refused"] =
      { symbol = "Text_RefusedToBuySlowpokeTail" },
    ["crystal.text.route_32.slowpoke_tail_too_expensive"] =
      { symbol = "Text_ThoughtKidsWereLoaded" },
    ["crystal.text.route_32.union_cave_sign"] =
      { symbol = "Route32UnionCaveSignText" },

    ["crystal.text.route_36.alan_after"] =
      { symbol = "SchoolboyAlanBooksText" },
    ["crystal.text.route_36.arthur_after"] =
      { symbol = "ArthurGaveGiftText" },
    ["crystal.text.route_36.arthur_intro"] =
      { symbol = "MeetArthurText" },
    ["crystal.text.route_36.floria"] = { symbol = "FloriaText1" },
    ["crystal.text.route_36.lass"] = { symbol = "Route36LassText" },
    ["crystal.text.route_36.mark_after"] =
      { symbol = "PsychicMarkAfterBattleText" },
    ["crystal.text.route_36.rock_smash_guy"] =
      { symbol = "RockSmashGuyText1" },
    ["crystal.text.route_36.route_sign"] =
      { symbol = "Route36SignText" },
    ["crystal.text.route_36.ruins_sign"] =
      { symbol = "RuinsOfAlphNorthSignText" },
    ["crystal.text.route_36.sudowoodo_attacks"] =
      { symbol = "SudowoodoAttackedText" },
    ["crystal.text.route_36.trainer_tips_dig"] =
      { symbol = "Route36TrainerTips2Text" },
    ["crystal.text.route_36.trainer_tips_stats"] =
      { symbol = "Route36TrainerTips1Text" },
    ["crystal.text.route_36.use_squirt_bottle"] =
      { symbol = "UseSquirtbottleText" },
    ["crystal.text.route_36.weird_tree"] =
      { symbol = "UsedSquirtbottleText" },

    ["crystal.text.violet.earl_asks_about_falkner"] =
      { symbol = "Text_EarlAsksIfYouBeatFalkner" },
    ["crystal.text.violet.earl_at_academy"] =
      { symbol = "Text_HereTeacherIAm" },
    ["crystal.text.violet.earl_follow"] = { symbol = "Text_FollowEarl" },
    ["crystal.text.violet.earl_very_nice"] =
      { symbol = "Text_VeryNiceIndeed" },
    ["crystal.text.violet_gym.statue"] = {
      symbol = "GymStatue_CityGymText",
      ramKeys = { "city" },
    },
    ["crystal.text.violet_gym.statue_champion"] = {
      symbol = "GymStatue_WinningTrainersText",
      ramKeys = { "leader", "player" },
    },
    ["crystal.text.violet_kyle_house.kyle"] =
      { symbol = "_NPCTradeCableText" },
    ["crystal.text.violet_kyle_house.pokefan"] =
      { symbol = "VioletKylesHousePokefanMText" },
    ["crystal.text.violet_nickname_house.bird"] =
      { symbol = "VioletNicknameSpeechHouseBirdText" },
    ["crystal.text.violet_nickname_house.lass"] =
      { symbol = "VioletNicknameSpeechHouseLassText" },
    ["crystal.text.violet_nickname_house.teacher"] =
      { symbol = "VioletNicknameSpeechHouseTeacherText" },
  },
}
