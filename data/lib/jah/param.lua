local Param = {}
Param.__index = Param

-- TODO: move round() function out of Param class to a more appropriate place since it is general
function Param.round(number, quant)
  if quant == 0 then
    return number
  else
    local quant_to_use
    if quant then
      quant_to_use = quant
    else
      quant_to_use = 1
    end
    return math.floor(number/quant_to_use + 0.5) * quant_to_use
  end
end

function Param.new(title, controlspec, formatter)
  local p = setmetatable({}, Param)
  p.title = title
  p.controlspec = controlspec
  p.formatter = formatter

  if controlspec and controlspec.default then
    p.value = controlspec:unmap(controlspec.default)
  else
    p.value = 0
  end
  return p
end

function Param:string(quant)
  if self.formatter then
    return self.formatter(self)
  else
    local mapped_value = self:mapped_value()
    local display_value
    if quant then
      display_value = Param.round(mapped_value, quant)
    else
      display_value = mapped_value
    end
    return self:string_format(display_value)
  end
end

function Param:string_format(value, units, title)
  local u
  if units then
    u = units
  elseif self.controlspec then
    u = self.controlspec.units
  else
    u = ""
  end
  return Param.stringify(title or self.title or "", u, value)
end

function Param.stringify(title, units, value)
  return title..": "..value.." "..units
end

function Param:set(value)
  clamped_value = util.clamp(value, 0, 1)
  if self.value ~= clamped_value then
    prev_value = self.value
    self.value = clamped_value
    self:bang()
  end
end

function Param:bang()
  if self.on_change then
    self.on_change(self.value, self.value)
  end
  if self.on_change_mapped then
    local value_mapped = self.controlspec:map(self.value)
    self.on_change_mapped(value_mapped, value_mapped)
  end
end

function Param:set_mapped_value(value)
  self:set(self.controlspec:unmap(value))
end

function Param:adjust(delta)
  self:set(self.value + delta)
end

function Param:adjust_wrap(delta) -- TODO: prune if not used anywhere
  self.value = util.clamp(self.value + delta, 0, 1)
end

function Param:mapped_value()
  return self.controlspec:map(self.value)
end

function Param:revert_to_default()
  if self.controlspec and self.controlspec.default then
    self:set_mapped_value(self.controlspec.default)
  else
    self:set(0)
  end
end

return Param
