local ActorCommandHandlers = {}

function ActorCommandHandlers.install(runner, services)
  local actors = assert(services.actors, "actor system is required")

  runner:register("actor.move", function(arguments)
    return actors:movementWait(arguments.id, arguments.directions)
  end)
  runner:register("actor.face", function(arguments)
    actors:face(arguments.id, arguments.direction)
  end)
  runner:register("actor.state.get", function(arguments)
    return actors:state(arguments.id)
  end)
  runner:register("actor.follow.start", function(arguments)
    actors:startFollowing(arguments.follower, arguments.leader)
  end)
  runner:register("actor.follow.stop", function(arguments)
    actors:stopFollowing(arguments.follower)
  end)
  runner:register("actor.emote", function(arguments)
    return actors:emoteWait(
      arguments.id,
      arguments.emote,
      arguments.duration or 0.75
    )
  end)
end

return ActorCommandHandlers
