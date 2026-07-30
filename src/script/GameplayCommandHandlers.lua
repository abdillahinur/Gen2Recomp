local GameplayCommandHandlers = {}

function GameplayCommandHandlers.install(runner, services)
  local world = assert(services.world, "world service is required")
  local actors = assert(services.actors, "actor system is required")
  local battles = assert(services.battles, "battle service is required")
  local audio = assert(services.audio, "audio service is required")

  runner:register("gameplay.battle", function(arguments)
    return battles:start(arguments)
  end)
  runner:register("world.warp", function(arguments)
    world:relocate(
      arguments.mapId,
      arguments.x,
      arguments.y,
      arguments.facing,
      "script_warp"
    )
  end)
  runner:register("world.map.load", function(arguments)
    world:relocate(
      arguments.mapId,
      arguments.x,
      arguments.y,
      arguments.facing,
      "map_change"
    )
  end)
  runner:register("world.map.change_block", function(arguments)
    world:changeBlock(
      arguments.mapId,
      arguments.blockX,
      arguments.blockY,
      arguments.blockId
    )
  end)
  runner:register("world.object.show", function(arguments)
    actors:setVisible(arguments.id, true)
  end)
  runner:register("world.object.hide", function(arguments)
    actors:setVisible(arguments.id, false)
  end)
  runner:register("world.object.place", function(arguments)
    actors:place(
      arguments.id,
      arguments.x,
      arguments.y,
      arguments.facing
    )
  end)
  runner:register("audio.music.play", function(arguments)
    audio:playMusic(arguments.id, arguments.options)
  end)
  runner:register("audio.music.stop", function(arguments)
    audio:stopMusic(arguments.options)
  end)
  runner:register("audio.sfx.play", function(arguments)
    audio:playSfx(arguments.id, arguments.options)
  end)
  runner:register("audio.cry.play", function(arguments)
    audio:playCry(arguments.id, arguments.options)
  end)
end

return GameplayCommandHandlers
