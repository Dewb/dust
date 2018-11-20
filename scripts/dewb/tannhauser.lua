-- tannhauser
-- genetic gate sequencer
--
-- enc1 = select
-- enc2 = ?
-- enc3 = ?
-- key2 = ?
-- key3 = ?
--
-- key1 = ALT
-- ALT-enc1 = bpm

engine.name = 'PolyPerc'

local g = grid.connect()

local BeatClock = require 'beatclock'
local clk = BeatClock.new()
local clk_midi = midi.connect()
clk_midi.event = function(data)
  clk:process_midi(data)
end

function init()

  clk.on_step = step
  clk.on_select_internal = function() clk:start() end
  clk.on_select_external = reset_pattern
  clk:add_clock_params()
  params:set("bpm",110)
  params:add_separator()

  params:read("dewb/tannhauser.pset")
  params:bang()

  clk:start()
  redraw()

end

function step()
  if g then
    gridredraw()
  end
  redraw()
end

function reset_pattern()
  one.pos = 0
  two.pos = 0
  clk:reset()
end

function g.event(x, y, z)
  if z > 0 then
    gridredraw()
    redraw()
  end
end

function gridredraw()
  g.all(0)
  g.refresh()
end

function enc(n, delta)
  redraw()
end

function key(n,z)
  if z == 1 then
    redraw()
  end
end

function redraw()
  screen.clear()
  screen.line_width(1)
  screen.aa(0)
  for i=0,3 do
    screen.move(i*128/4, 0)
    screen.line_rel(0, 64)
  end
  for i=0,2 do
    screen.move(0, i*64/3)
    screen.line_rel(128, 0)
  end
  screen.stroke()
  screen.update()
end

