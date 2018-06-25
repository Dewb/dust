-- deep navigation with joystick

engine.name = 'Why'


local hid = require 'hid'

local func_button = function(name)
  return function(val)
    print(name, ": ", val)
  end
end

local axes = {}

local func_axis = function(name, min, max, flip)
  axes[name] = { 
    val = (min+max)/2, 
    center = (min+max)/2, 
    width = max-min, 
    min = min,
    max = max
  }
    
  return function(val)
    if flip then
      axes[name]["val"] = axes[name]["max"] - val
    else
      axes[name]["val"] = val
    end
  end
end


--- local variables
local pad = nil
local callbacks = {
BTN_TRIGGER = func_button("trigger"),
BTN_THUMB = func_button("thumb 1"),
BTN_THUMB2 = func_button("thumb 2"),
BTN_TOP = func_button("top 1"),
BTN_TOP2 = func_button("top 2"),
BTN_PINKIE = func_button("pinkie"),
BTN_BASE = func_button("base 1"),
BTN_BASE2 = func_button("base 2"),
BTN_BASE3 = func_button("base 3"),
BTN_BASE4 = func_button("base 4"),
BTN_BASE5 = func_button("base 5"),
BTN_BASE6 = func_button("base 6"),
ABS_Y = func_axis("y axis", 0, 1024),
ABS_HAT0X = func_axis("hat x", -1, 1),
ABS_HAT0Y = func_axis("hat y", -1, 1),
ABS_RZ = func_axis("z rotation", 0, 255),
ABS_THROTTLE = func_axis("throttle", 0, 255),
ABS_X = func_axis("x axis", 0, 1024)
}

local screen_framerate = 15
local screen_refresh_metro
      
norns.script.cleanup = function()
   if pad then pad:clearCallbacks() end
   pad = nil
   callbacks = nil
end

local setPad = function(device)
   print("grabbing device: ")
   device:print()
   -- stop any callbacks we may have added to the last device we used
   if pad then
      print("clearing old callbacks")
      pad.callbacks = {}
      --pad:clearCallbacks()
   end   
   -- use the new device
   pad = device
   for code,func in pairs(callbacks) do
      print(code, func)
      pad.callbacks[code] = func
   end

end

-- on startup, see if there's already a gamepad connected
pad = hid.find_device_supporting('EV_ABS', 'ABS_X') -- << FIXME, shouldn't need ev type
if pad then setPad(pad) end

-- when a new device is added, see if its a gamepad
hid.add = function (device)
   setPad(device)
end

local notes = {}

function init()

  screen_refresh_metro = metro.alloc()
  screen_refresh_metro.callback = function(stage)
    update()
    redraw()
  end
  screen_refresh_metro:start(1 / screen_framerate)
  
  
  for i = 1, 30 do
    notes[i] = math.random(21, 84)
  end
  
end

function update()
  
end

function delta_axis(axis, delta)
  axis["val"] = util.clamp(axis["val"] + delta, axis["min"], axis["max"])
end
  
local editaxis = 0
local edit_axis_list = {"x axis", "y axis", "throttle"}

function enc(n, delta)
  if n == 1 then
    mix:delta("output", delta)
    print(delta)
  elseif n == 2 then
    delta_axis(axes[edit_axis_list[editaxis+1]], delta)
  end
end

function key(n, z)
  if n == 2 and z == 1 then
    editaxis = (editaxis + 1) % #edit_axis_list
  end
end

function redraw()
  screen.clear()

  screen.level(1)
  for i = 1, 30 do
    screen_pixel(i-1, notes[i] - 32)
    --screen_pixel(i*2-1, notes[i] - 32)
  end
  screen.stroke()

  draw_two_axis_circle(28, 85, 32, axes["x axis"], axes["y axis"], editaxis < 2 and 15 or 5)
  draw_vertical_axis(122, 5, 60, 6, axes["throttle"], editaxis == 2 and 15 or 5)

  screen.update()
end  
  
function screen_pixel(x, y)
  screen.rect(x-0.25,y-0.25,0.5,0.5)
end

function draw_two_axis_circle(radius, origin_x, origin_y, axis_x, axis_y, brightness)

  screen.close()
  screen.line_width(4)
  screen.level(4)
  screen.move(origin_x + radius, radius)
  screen.circle(origin_x, origin_y, radius)  
  screen.move(origin_x, origin_y)

  local ax = origin_x + math.floor((axis_x["val"] - axis_x["center"])*(2*radius/axis_x["width"]))
  local ay = origin_y + math.floor((axis_y["val"] - axis_y["center"])*(2*radius/axis_y["width"]))
  screen.line(ax, ay)
  screen.stroke()
  
  screen.circle(ax, ay, 3)
  screen.level(brightness)
  screen.fill()  
    
end


function draw_vertical_box(x, y1, y2, width)
  
  local dx = width/2
  local dy = 0

  screen.move(math.floor(x - dx), math.floor(y1 - dy))
  screen.line(math.floor(x - dx), math.floor(y2 - dy))
  screen.line(math.floor(x + dx), math.floor(y2 + dy))
  screen.line(math.floor(x + dx), math.floor(y1 + dy))
  screen.line(math.floor(x - dx), math.floor(y1 - dy))

end

function draw_vertical_axis(x, y1, y2, width, axis, brightness)
  local length = y2 - y1

  screen.close()

  screen.level(2)
  draw_vertical_box(x, y1, y2, width)
  screen.stroke()

  screen.level(brightness)
  draw_vertical_box(x, y1 + 1 + (y2 - y1 - 2) * axis["val"]/axis["max"], y2 - 1, width - 2)
  screen.fill()
end

--[[
function draw_linear_box(x1, y1, x2, y2, width)
  
  local dx = 0
  if x2 - x1 ~= 0 then dx = width/2 * (y2 - y1) / (x2 - x1) end
  local dy = 0
  if y2 - y1 ~= 0 then dy = -width/2 * (x2 - x1) / (y2 - y1) end 

  screen.move(math.floor(x1 - dx), math.floor(y1 - dy))
  screen.line(math.floor(x2 - dx), math.floor(y2 - dy))
  screen.line(math.floor(x2 + dx), math.floor(y2 + dy))
  screen.line(math.floor(x1 + dx), math.floor(y1 + dy))
  screen.line(math.floor(x1 - dx), math.floor(y1 - dy))

end

function draw_arbitrary_axis(x1, y1, x2, y2, width, axis)

  local length = math.sqrt(math.pow(x2-x1, 2) + math.pow(y2-y1, 2))
  local dx = 0
  if x2 - x1 ~= 0 then dx = (y2 - y1) / (x2 - x1) end
  local dy = 0
  if y2 - y1 ~= 0 then dy = -(x2 - x1) / (y2 - y1) end 
  local x3 = x1 + dx * axis["val"]/axis["max"] * length
  local y3 = y1 - dy * axis["val"]/axis["max"] * length
  local w2 = width/2

  screen.close()

  screen.level(2)
  draw_linear_box(x1, y1, x2, y2, width)
  screen.stroke()

  screen.level(5)
  draw_linear_box(x1 + dx * w2, y1 - dy * w2, x3 - dx * w2, y3 + dy * w2, width/2)
  screen.fill()
  
end
--]]

