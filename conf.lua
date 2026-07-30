function love.conf(t)
  t.identity = "gen2recomp"
  t.version = "11.0"
  t.console = false

  t.window.title = "Gen2Recomp"
  t.window.width = 640
  t.window.height = 576
  t.window.resizable = true
  t.window.minwidth = 320
  t.window.minheight = 288
  t.window.vsync = 1

  t.modules.physics = false
  t.modules.video = false
end

