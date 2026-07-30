local CommandRequest = require("src.script.CommandRequest")

local Commands = {}

function Commands.request(name, arguments)
  local thread, isMain = coroutine.running()
  if not thread or isMain then
    error("script commands can only run inside a script coroutine", 2)
  end
  return coroutine.yield(CommandRequest.new(name, arguments))
end

function Commands.hasFlag(id)
  return Commands.request("state.flag.get", { id = id })
end

function Commands.setFlag(id)
  return Commands.request("state.flag.set", { id = id })
end

function Commands.clearFlag(id)
  return Commands.request("state.flag.clear", { id = id })
end

function Commands.getScene(scope)
  return Commands.request("state.scene.get", { scope = scope })
end

function Commands.setScene(scope, scene)
  return Commands.request("state.scene.set", {
    scope = scope,
    scene = scene,
  })
end

function Commands.getVariable(id, default)
  return Commands.request("state.variable.get", {
    id = id,
    default = default,
  })
end

function Commands.setVariable(id, value)
  return Commands.request("state.variable.set", {
    id = id,
    value = value,
  })
end

function Commands.text(id, substitutions)
  return Commands.request("ui.text", {
    id = id,
    substitutions = substitutions,
  })
end

function Commands.choice(id, options)
  return Commands.request("ui.choice", {
    id = id,
    options = options,
  })
end

function Commands.move(id, directions)
  return Commands.request("actor.move", {
    id = id,
    directions = directions,
  })
end

function Commands.face(id, direction)
  return Commands.request("actor.face", {
    id = id,
    direction = direction,
  })
end

function Commands.actorState(id)
  return Commands.request("actor.state.get", { id = id })
end

function Commands.follow(follower, leader)
  return Commands.request("actor.follow.start", {
    follower = follower,
    leader = leader,
  })
end

function Commands.stopFollowing(follower)
  return Commands.request("actor.follow.stop", {
    follower = follower,
  })
end

function Commands.emote(id, emote, duration)
  return Commands.request("actor.emote", {
    id = id,
    emote = emote,
    duration = duration,
  })
end

function Commands.battle(kind, opponentId, options)
  return Commands.request("gameplay.battle", {
    kind = kind,
    opponentId = opponentId,
    options = options,
  })
end

function Commands.warp(mapId, x, y, facing)
  return Commands.request("world.warp", {
    mapId = mapId,
    x = x,
    y = y,
    facing = facing,
  })
end

function Commands.loadMap(mapId, x, y, facing)
  return Commands.request("world.map.load", {
    mapId = mapId,
    x = x,
    y = y,
    facing = facing,
  })
end

function Commands.changeBlock(mapId, blockX, blockY, blockId)
  return Commands.request("world.map.change_block", {
    mapId = mapId,
    blockX = blockX,
    blockY = blockY,
    blockId = blockId,
  })
end

function Commands.showObject(id)
  return Commands.request("world.object.show", { id = id })
end

function Commands.hideObject(id)
  return Commands.request("world.object.hide", { id = id })
end

function Commands.placeObject(id, x, y, facing)
  return Commands.request("world.object.place", {
    id = id,
    x = x,
    y = y,
    facing = facing,
  })
end

function Commands.playMusic(id, options)
  return Commands.request("audio.music.play", {
    id = id,
    options = options,
  })
end

function Commands.stopMusic(options)
  return Commands.request("audio.music.stop", { options = options })
end

function Commands.playSfx(id, options)
  return Commands.request("audio.sfx.play", {
    id = id,
    options = options,
  })
end

function Commands.playCry(id, options)
  return Commands.request("audio.cry.play", {
    id = id,
    options = options,
  })
end

function Commands.setupClock()
  return Commands.request("system.clock.setup")
end

function Commands.selectName(gender)
  return Commands.request("ui.name.select", { gender = gender })
end

function Commands.pause(seconds)
  return Commands.request("system.wait", { seconds = seconds })
end

function Commands.givePokemon(speciesId, level, heldItemId)
  return Commands.request("party.pokemon.give", {
    speciesId = speciesId,
    level = level,
    heldItemId = heldItemId,
  })
end

function Commands.giveItem(itemId, count)
  return Commands.request("inventory.item.give", {
    itemId = itemId,
    count = count,
  })
end

function Commands.registerPhoneContact(id)
  return Commands.request("phone.contact.register", { id = id })
end

return Commands
