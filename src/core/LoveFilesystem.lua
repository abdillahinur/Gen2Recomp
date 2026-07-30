local LoveFilesystem = {}
LoveFilesystem.__index = LoveFilesystem

local function assertRelative(path)
  if type(path) ~= "string" or path == "" then
    error("filesystem path must be a non-empty relative path", 3)
  end
  if path:sub(1, 1) == "/"
      or path:find("\\", 1, true)
      or path:find(":", 1, true)
      or path:find("//", 1, true)
      or path:sub(-1) == "/" then
    error("filesystem path is not a normalized relative path", 3)
  end
  for segment in path:gmatch("[^/]+") do
    if segment == "." or segment == ".." then
      error("filesystem path contains a traversal segment", 3)
    end
  end
  return path
end

local function join(left, right)
  return left:gsub("[/\\]+$", "") .. "/" .. right
end

function LoveFilesystem.new(loveFilesystem)
  loveFilesystem = loveFilesystem
    or (love and love.filesystem)
  if type(loveFilesystem) ~= "table" then
    error("LÖVE filesystem module is unavailable", 2)
  end

  local saveDirectory = loveFilesystem.getSaveDirectory()
  if type(saveDirectory) ~= "string" or saveDirectory == "" then
    error("LÖVE save directory is unavailable", 2)
  end

  return setmetatable({
    love = loveFilesystem,
    saveDirectory = saveDirectory,
  }, LoveFilesystem)
end

function LoveFilesystem:info(path)
  return self.love.getInfo(assertRelative(path))
end

function LoveFilesystem:createDirectory(path)
  local ok, message = self.love.createDirectory(assertRelative(path))
  if not ok then
    return nil, message or "could not create directory"
  end
  return true
end

function LoveFilesystem:write(path, data)
  assertRelative(path)
  if type(data) ~= "string" then
    error("filesystem write data must be a string", 2)
  end
  local ok, message = self.love.write(path, data)
  if not ok then
    return nil, message or "could not write file"
  end
  return true
end

function LoveFilesystem:read(path)
  local data, message = self.love.read(assertRelative(path))
  if data == nil then
    return nil, message or "could not read file"
  end
  return data
end

function LoveFilesystem:list(path)
  local items = self.love.getDirectoryItems(assertRelative(path))
  if type(items) ~= "table" then
    return nil, "could not list directory"
  end
  table.sort(items)
  return items
end

function LoveFilesystem:removeTree(path)
  path = assertRelative(path)
  local info = self.love.getInfo(path)
  if not info then
    return true
  end

  if info.type == "directory" then
    local items = self.love.getDirectoryItems(path)
    for _, name in ipairs(items) do
      local ok, message = self:removeTree(path .. "/" .. name)
      if not ok then
        return nil, message
      end
    end
  end

  local ok = self.love.remove(path)
  if not ok then
    return nil, "could not remove " .. path
  end
  return true
end

function LoveFilesystem:rename(source, destination)
  source = assertRelative(source)
  destination = assertRelative(destination)
  if self.love.getInfo(destination) then
    return nil, "rename destination already exists"
  end

  local sourcePath = join(self.saveDirectory, source)
  local destinationPath = join(self.saveDirectory, destination)
  local ok, message, code = os.rename(sourcePath, destinationPath)
  if not ok then
    return nil, message or (code and tostring(code)) or "rename failed"
  end
  return true
end

return LoveFilesystem
