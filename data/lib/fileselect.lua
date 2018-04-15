-- fileselect utility
-- reroutes redraw/enc/key

local fs = {}

function fs.enter(folder, callback)
  fs.folders = {}
  fs.list = {}
  fs.pos = 1 
  fs.depth = 0
  fs.folder = folder
  fs.callback = callback
  fs.done = false
  fs.path = nil 

  if fs.folder:sub(-1,-1) ~= "/" then
    fs.folder = fs.folder .. "/"
  end 

  fs.list = fs.getlist()
  fs.len = tab.count(fs.list)

  fs.key_restore = key
  fs.enc_restore = enc
  fs.redraw_restore = redraw
  key = fs.key
  enc = fs.enc
  redraw = fs.redraw
  norns.menu.init()
end

function fs.exit()
  key = fs.key_restore
  enc = fs.enc_restore
  redraw = fs.redraw_restore 
  norns.menu.init()
  if fs.path then fs.callback(fs.path)
  else fs.callback("cancel") end
end


fs.getdir = function()
  local path = fs.folder
  for k,v in pairs(fs.folders) do
    path = path .. v
  end
  --print("path: "..path)
  return path
end

fs.getlist = function()
  return util.scandir(fs.getdir())
end

fs.key = function(n,z) 
  -- back
  if n==2 and z==1 then
    if fs.depth > 0 then
      --print('back')
      fs.folders[fs.depth] = nil
      fs.depth = fs.depth - 1
      fs.list = util.scandir(fs.getdir())
      fs.len = tab.count(fs.list)
      fs.pos = 0 
    else
      fs.done = true
    end
    -- select
  elseif n==3 and z==1 then
    fs.file = fs.list[fs.pos+1]
    if string.find(fs.file,'/') then
      --print("folder")
      fs.depth = fs.depth + 1
      fs.folders[fs.depth] = fs.file
      fs.list = util.scandir(fs.getdir())
      fs.len = tab.count(fs.list)
      fs.pos = 0
      redraw()
    else
      local path = fs.folder 
      for k,v in pairs(fs.folders) do
        path = path .. v
      end
      fs.path = path .. fs.file
      fs.done = true
    end
  elseif z == 0 and fs.done == true then
    fs.exit()
  end 
end

fs.enc = function(n,d)
  if n==2 then
    fs.pos = util.clamp(fs.pos + d, 0, fs.len - 1)
    redraw()
  end
end


fs.redraw = function()
  local i
  screen.clear()
  screen.move(0,10)
  screen.level(15)
  for i=1,6 do
    if (i > 2 - fs.pos) and (i < fs.len - fs.pos + 3) then
      screen.move(0,10*i)
      local line = fs.list[i+fs.pos-2]
      if(i==3) then
        screen.level(15)
      else
        screen.level(4)
      end
      --screen.text(string.upper(line))
      screen.text(line)
    end
  end
  screen.update()
end

return fs
