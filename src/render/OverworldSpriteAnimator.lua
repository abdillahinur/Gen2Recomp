-- Pure-Lua overworld sprite frame selector for Crystal-style sheets.
--
-- pret/pokecrystal reference (no ROM bytes in-repo):
--   * Standing sheet: 12 tiles = down / up / left, 4 tiles (16x16) each.
--     Right facing = left sheet + OAM X flip.
--   * Walking sheet: next 12 tiles in the same GFX blob (GetUsedSprite
--     advances the source by the standing length). Current importer only
--     keeps the standing half (tileCount == 12); tileCount >= 24 unlocks
--     the walk rows as frame indices 3..5.
--   * Walk cycle: data/sprite_anims/framesets.asm Frameset_RedWalk /
--     Frameset_BlueWalk -- four beats of 8 sprite-anim ticks:
--       0: WALK_1, 1: WALK_2, 2: WALK_1, 3: WALK_2 + B_OAM_XFLIP
--
-- STEP_FRAMES replaces the old World.STEP_SECONDS = 0.18 wall-clock step.
-- 16 integer frames at 60 Hz (~0.267s) matches the common Crystal step
-- length; the prior 0.18s timing was host smoke only.

local OverworldSpriteAnimator = {}

OverworldSpriteAnimator.CHRIS_SPRITE_ID = 1
OverworldSpriteAnimator.KRIS_SPRITE_ID = 96
OverworldSpriteAnimator.STEP_FRAMES = 16
OverworldSpriteAnimator.FRAME_HZ = 60
OverworldSpriteAnimator.FRAME_SECONDS =
  1 / OverworldSpriteAnimator.FRAME_HZ
OverworldSpriteAnimator.STEP_SECONDS =
  OverworldSpriteAnimator.STEP_FRAMES
  * OverworldSpriteAnimator.FRAME_SECONDS

local WALKING_SPRITE = 0
local STANDING_SPRITE = 1
local STILL_SPRITE = 2

local function facingBase(facing)
  if facing == "up" then
    return 1, false
  elseif facing == "left" then
    return 2, false
  elseif facing == "right" then
    return 2, true
  end
  return 0, false
end

function OverworldSpriteAnimator.spriteIdForGender(gender)
  if gender == "female" then
    return OverworldSpriteAnimator.KRIS_SPRITE_ID
  end
  return OverworldSpriteAnimator.CHRIS_SPRITE_ID
end

function OverworldSpriteAnimator.walkPhase(framesElapsed, stepFrames)
  stepFrames = stepFrames or OverworldSpriteAnimator.STEP_FRAMES
  if type(framesElapsed) ~= "number" or framesElapsed ~= framesElapsed then
    return 0
  end
  framesElapsed = math.floor(framesElapsed)
  if framesElapsed < 0 then
    framesElapsed = 0
  end
  if framesElapsed >= stepFrames then
    framesElapsed = stepFrames - 1
  end
  return math.floor(framesElapsed * 4 / stepFrames) % 4
end

-- Advance a move clock by dt seconds into integer frames.
-- mutates move: { frameAccumulator, framesElapsed, animPhase }
function OverworldSpriteAnimator.advanceMove(move, dt, stepFrames)
  stepFrames = stepFrames or OverworldSpriteAnimator.STEP_FRAMES
  local frameSeconds = OverworldSpriteAnimator.FRAME_SECONDS
  if type(dt) ~= "number" or dt ~= dt or dt < 0 then
    dt = 0
  end
  move.frameAccumulator = (move.frameAccumulator or 0) + dt
  move.framesElapsed = move.framesElapsed or 0
  while move.frameAccumulator + 1e-12 >= frameSeconds
      and move.framesElapsed < stepFrames do
    move.frameAccumulator = move.frameAccumulator - frameSeconds
    move.framesElapsed = move.framesElapsed + 1
  end
  move.animPhase =
    OverworldSpriteAnimator.walkPhase(move.framesElapsed, stepFrames)
  local alpha = move.framesElapsed / stepFrames
  local done = move.framesElapsed >= stepFrames
  return alpha, done
end

function OverworldSpriteAnimator.select(options)
  options = options or {}
  local tileCount = options.tileCount or 0
  local kind = options.kind
  local facing = options.facing or "down"
  local moving = options.moving and true or false
  local phase = options.phase or 0
  if type(phase) ~= "number" or phase ~= phase then
    phase = 0
  end
  phase = math.floor(phase) % 4

  if tileCount < 12 or kind == STILL_SPRITE then
    return { frame = 0, flipX = false }
  end

  local frame, flipX = facingBase(facing)

  -- STANDING_SPRITE has facings but no walking sheet in Crystal VRAM.
  if not moving or kind == STANDING_SPRITE then
    return { frame = frame, flipX = flipX }
  end

  -- Default nil kind to WALKING_SPRITE (Crystal player/NPC walkers).
  if kind ~= nil and kind ~= WALKING_SPRITE then
    return { frame = frame, flipX = flipX }
  end

  local useWalkSheet = phase == 1 or phase == 3
  local extraFlip = phase == 3
  if useWalkSheet and tileCount >= 24 then
    frame = frame + 3
  end
  if extraFlip then
    flipX = not flipX
  end
  return { frame = frame, flipX = flipX }
end

OverworldSpriteAnimator.WALKING_SPRITE = WALKING_SPRITE
OverworldSpriteAnimator.STANDING_SPRITE = STANDING_SPRITE
OverworldSpriteAnimator.STILL_SPRITE = STILL_SPRITE

return OverworldSpriteAnimator
