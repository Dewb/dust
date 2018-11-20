local MasterClock = {}
MasterClock.__index = MasterClock

function MasterClock.new()
  local i = {}
  setmetatable(i, MasterClock)
  
  i.playing = false
  i.ticks_per_step = 6
  i.current_ticks = i.ticks_per_step - 1
  i.steps_per_beat = 4
  i.beats_per_bar = 4
  i.step = i.steps_per_beat - 1
  i.beat = i.beats_per_bar - 1
  i.external = false
  i.send = false
  
  i.clock_source = 1
  i.midi_input_device = nil
  i.midi_output_devices = {}
  
  i.metro = metro.alloc()
  i.metro.count = -1
  i.metro.callback = function() i:tick() end

  i.child_clocks = {}
  setmetatable(i.child_clocks, { __mode = "k" }) -- enable weak keys 
  i.num_child_clocks = 0

  i:bpm_change(110)
  i:clock_source_change(i.clock_source)

  return i
end

function MasterClock:send_midi(msg)
  if self.send then
    for x, device in pairs(self.midi_output_devices) do
      device.send(msg)
    end
  end
end

function MasterClock:init_midi(source_device)
  self.midi_input_device = nil
  self.midi_output_devices = {}
  collectgarbage()

  if source_device >= 1 and source_device <= 4 then
    self.midi_input_device = midi.connect(source_device)
    self.midi_input_device.event = function(data) self:process_midi(data) end
  end
  
  for i = 1, 4 do
    if i ~= source_device then
      table.insert(self.midi_output_devices, midi.connect(i))
    end
  end
end

function MasterClock:start()
  self.playing = true
  if not self.external then
    self.metro:start()
  end
  self.current_ticks = self.ticks_per_step - 1
  self:send_midi({251})
  for child, _ in pairs(self.child_clocks) do
    child.on_start()
  end
end

function MasterClock:stop()
  self.playing = false
  self.metro:stop()
  self:send_midi({252})
  for child, _ in pairs(self.child_clocks) do
    child.on_stop()
  end
end

function MasterClock:advance_step()
  self.step = (self.step + 1) % self.steps_per_beat
  if self.step == 0 then
    self.beat = (self.beat + 1) % self.beats_per_bar
  end
  for child, _ in pairs(self.child_clocks) do
    child.step = self.step
    child.beat = self.beat
    child.on_step()
  end
end

function MasterClock:tick()
  self.current_ticks = (self.current_ticks + 1) % self.ticks_per_step
  if self.playing and self.current_ticks == 0 then
    self:advance_step()
  end
  self:send_midi({248})
end

function MasterClock:reset(dev_id)
  self.step = self.steps_per_beat - 1
  self.beat = self.beats_per_bar - 1
  self.current_ticks = self.ticks_per_step - 1
  if self.playing then 
    self:send_midi({250})
  else -- force reseting while stopped requires a start/stop (??)
    self:send_midi({250, 252})
  end
end

function MasterClock:clock_source_change(source)
  self.clock_source = source
  self.current_ticks = self.ticks_per_step - 1
  
  if source == 1 then -- internal clock
    self.external = false
    self:init_midi(-1)
  
  elseif source == 6 then -- ableton link
    -- todo: link support
    self.external = true
    self:init_midi(-1)
    
  else -- external midi
    self.external = true
    self:init_midi(source - 1)
  end
  
  if self.external then
    self.metro:stop()
    for child, _ in pairs(self.child_clocks) do
      child.on_select_external()
    end
  else
    if self.playing then
      self.metro:start()
    end
    for child, _ in pairs(self.child_clocks) do
      child.on_select_internal()
    end
  end
end

function MasterClock:bpm_change(bpm)
  self.bpm = bpm
  self.metro.time = 60/(self.ticks_per_step * self.steps_per_beat * self.bpm)
  for child, _ in pairs(self.child_clocks) do
    child.on_bpm_change(bpm)
  end
end

function MasterClock:add_clock_params()
  params:add_option("clock", "clock source", {"internal", "midi 1", "midi 2", "midi 3", "midi 4", "link (todo)"}, self.clock_source)
  params:set_action("clock", function(x) self:clock_source_change(x) end)
  params:add_number("bpm", "bpm", 1, 480, self.bpm)
  params:set_action("bpm", function(x) self:bpm_change(x) end)
  params:add_option("clock_out", "midi clock out", { "no", "yes" }, self.send or 2 and 1)
  params:set_action("clock_out", function(x) if x == 1 then self.send = false else self.send = true end end)
end


function MasterClock:process_midi(data)
  status = data[1]

  if self.external then 
    if status == 248 then -- midi clock
      self:tick(id)
    elseif status == 250 then -- midi clock start
      self:reset(id)
      self:start(id)
    elseif status == 251 then -- midi clock continue
      self:start(id)
    elseif status == 252 then -- midi clock stop
      self:stop(id)
    end
  end
end

function MasterClock:add_child(child)
  if (not self.child_clocks[child]) then
    self.child_clocks[child] = true
    self.num_child_clocks = self.num_child_clocks + 1
  end
end

function MasterClock:remove_child(child)
  if (self.child_clocks[child]) then
    self.child_clocks[child] = nil
    self.num_child_clocks = self.num_child_clocks - 1
  end
end

function MasterClock:num_children()
  return self.num_child_clocks
end

-- -- --

local theMasterClock = MasterClock.new();

-- -- --

local BeatClock = {}
local BeatClockMeta = {}
BeatClockMeta.__index = BeatClock
BeatClockMeta.__gc = function(self) 
  print("Garbage collecting clock '" .. self.name .. "'")
  theMasterClock:remove_child(self)
end
  
function BeatClock.new(options)
  local i = {}
  setmetatable(i, BeatClockMeta)
  
  local opts = options or {}
  i.name = opts.name or "clock " .. (theMasterClock:num_children() + 1)
  i.multiply = opts.multiply or 1
  i.divide = opts.divide or 1
  
  i.step = 0
  i.beat = 0

  i.on_step = function() print(i.name .. " executing step") end
  i.on_start = function() end
  i.on_stop = function() end
  i.on_bpm_change = function(bpm) end
  i.on_select_internal = function() end
  i.on_select_external = function() end

  theMasterClock:add_child(i)
  i.master = theMasterClock

  return i
end  

function BeatClock:add_clock_params()
  theMasterClock:add_clock_params()
end

function BeatClock:start()
  -- todo: allow clocks to start and stop independently
  theMasterClock:start()
end

function BeatClock:stop()
  -- todo: allow clocks to start and stop independently
  theMasterClock:stop()
end

function BeatClock:reset()
  -- todo: allow clocks to start and stop independently
  theMasterClock:stop()
end

function BeatClock:bpm_change(bpm)
  -- todo: allow clocks to be detached from the master clock
  theMasterClock:bpm_change(bpm)
end


return BeatClock
