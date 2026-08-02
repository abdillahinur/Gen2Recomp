return function(test, equal, truthy)
  local Animator = require("src.render.OverworldSpriteAnimator")

  local function select(options)
    return Animator.select(options)
  end

  test("OverworldSpriteAnimator maps gender to Chris and Kris ids", function()
    equal(Animator.spriteIdForGender(nil), 1)
    equal(Animator.spriteIdForGender("male"), 1)
    equal(Animator.spriteIdForGender("female"), 96)
  end)

  test("OverworldSpriteAnimator keeps 4-tile still sprites on frame 0", function()
    for _, facing in ipairs({ "down", "up", "left", "right" }) do
      local standing = select({
        tileCount = 4,
        kind = Animator.STILL_SPRITE,
        facing = facing,
        moving = false,
        phase = 0,
      })
      equal(standing.frame, 0, facing .. " still frame")
      equal(standing.flipX, false, facing .. " still flip")
      local walking = select({
        tileCount = 4,
        facing = facing,
        moving = true,
        phase = 3,
      })
      equal(walking.frame, 0, facing .. " still walk frame")
      equal(walking.flipX, false, facing .. " still walk flip")
    end
  end)

  -- Standing 12-tile mapping matches the previous facingFrame helper.
  test("OverworldSpriteAnimator stands 12-tile facings like facingFrame", function()
    local cases = {
      { facing = "down", frame = 0, flipX = false },
      { facing = "up", frame = 1, flipX = false },
      { facing = "left", frame = 2, flipX = false },
      { facing = "right", frame = 2, flipX = true },
    }
    for _, case in ipairs(cases) do
      local result = select({
        tileCount = 12,
        kind = Animator.WALKING_SPRITE,
        facing = case.facing,
        moving = false,
        phase = 2,
      })
      equal(result.frame, case.frame, case.facing .. " frame")
      equal(result.flipX, case.flipX, case.facing .. " flip")
    end
  end)

  -- Frameset_RedWalk / Frameset_BlueWalk four-beat cycle against the
  -- standing sheet only (imported tileCount == 12 has no walk rows yet).
  test("OverworldSpriteAnimator walks 12-tile via RedWalk phase flips", function()
    local down = {
      { phase = 0, frame = 0, flipX = false },
      { phase = 1, frame = 0, flipX = false },
      { phase = 2, frame = 0, flipX = false },
      { phase = 3, frame = 0, flipX = true },
    }
    for _, case in ipairs(down) do
      local result = select({
        tileCount = 12,
        facing = "down",
        moving = true,
        phase = case.phase,
      })
      equal(result.frame, case.frame, "down phase " .. case.phase .. " frame")
      equal(result.flipX, case.flipX, "down phase " .. case.phase .. " flip")
    end

    local right = {
      { phase = 0, frame = 2, flipX = true },
      { phase = 1, frame = 2, flipX = true },
      { phase = 2, frame = 2, flipX = true },
      { phase = 3, frame = 2, flipX = false },
    }
    for _, case in ipairs(right) do
      local result = select({
        tileCount = 12,
        facing = "right",
        moving = true,
        phase = case.phase,
      })
      equal(result.frame, case.frame, "right phase " .. case.phase .. " frame")
      equal(result.flipX, case.flipX, "right phase " .. case.phase .. " flip")
    end
  end)

  -- Synthetic 24-tile sheet: stand rows 0..2, walk rows 3..5.
  test("OverworldSpriteAnimator walks 24-tile stand/walk rows", function()
    local result = select({
      tileCount = 24,
      facing = "up",
      moving = true,
      phase = 1,
    })
    equal(result.frame, 4)
    equal(result.flipX, false)

    result = select({
      tileCount = 24,
      facing = "left",
      moving = true,
      phase = 3,
    })
    equal(result.frame, 5)
    equal(result.flipX, true)

    result = select({
      tileCount = 24,
      facing = "down",
      moving = true,
      phase = 0,
    })
    equal(result.frame, 0)
    equal(result.flipX, false)
  end)

  test("OverworldSpriteAnimator standing kind never takes walk rows", function()
    local result = select({
      tileCount = 24,
      kind = Animator.STANDING_SPRITE,
      facing = "down",
      moving = true,
      phase = 3,
    })
    equal(result.frame, 0)
    equal(result.flipX, false)
  end)

  test("OverworldSpriteAnimator wraps walk phases across a step", function()
    equal(Animator.walkPhase(0, 16), 0)
    equal(Animator.walkPhase(3, 16), 0)
    equal(Animator.walkPhase(4, 16), 1)
    equal(Animator.walkPhase(8, 16), 2)
    equal(Animator.walkPhase(12, 16), 3)
    equal(Animator.walkPhase(15, 16), 3)
    equal(Animator.walkPhase(16, 16), 3)
    equal(Animator.walkPhase(100, 16), 3)
  end)

  test("OverworldSpriteAnimator advances move clocks in integer frames", function()
    local move = {
      frameAccumulator = 0,
      framesElapsed = 0,
    }
    local alpha, done = Animator.advanceMove(
      move,
      Animator.STEP_SECONDS / 2,
      Animator.STEP_FRAMES
    )
    equal(move.framesElapsed, 8)
    equal(done, false)
    truthy(math.abs(alpha - 0.5) < 1e-9)
    equal(move.animPhase, 2)

    alpha, done = Animator.advanceMove(
      move,
      Animator.STEP_SECONDS / 2,
      Animator.STEP_FRAMES
    )
    equal(move.framesElapsed, 16)
    equal(done, true)
    truthy(math.abs(alpha - 1) < 1e-9)
  end)

  test("OverworldSpriteAnimator documents STEP_FRAMES replacing 0.18s", function()
    equal(Animator.STEP_FRAMES, 16)
    equal(Animator.FRAME_HZ, 60)
    truthy(math.abs(Animator.STEP_SECONDS - 16 / 60) < 1e-12)
  end)
end
