local MemoryFilesystem = {}
MemoryFilesystem.__index = MemoryFilesystem

local function parent(path)
  return path:match("^(.*)/[^/]+$") or ""
end

local function hasPrefix(path, root)
  return path == root or path:sub(1, #root + 1) == root .. "/"
end

function MemoryFilesystem.new()
  return setmetatable({
    directories = { [""] = true },
    files = {},
    events = {},
    renameFailure = nil,
  }, MemoryFilesystem)
end

function MemoryFilesystem:info(path)
  if self.directories[path] then
    return { type = "directory" }
  end
  local data = self.files[path]
  if data ~= nil then
    return { type = "file", size = #data }
  end
  return nil
end

function MemoryFilesystem:createDirectory(path)
  local current = ""
  for segment in path:gmatch("[^/]+") do
    current = current == "" and segment or current .. "/" .. segment
    if self.files[current] ~= nil then
      return nil, "a file blocks the directory"
    end
    self.directories[current] = true
  end
  self.events[#self.events + 1] = { operation = "mkdir", path = path }
  return true
end

function MemoryFilesystem:write(path, data)
  if not self.directories[parent(path)] then
    return nil, "parent directory does not exist"
  end
  if self.directories[path] then
    return nil, "path is a directory"
  end
  self.files[path] = data
  self.events[#self.events + 1] = { operation = "write", path = path }
  return true
end

function MemoryFilesystem:read(path)
  local data = self.files[path]
  if data == nil then
    return nil, "file does not exist"
  end
  return data
end

function MemoryFilesystem:list(path)
  if not self.directories[path] then
    return nil, "directory does not exist"
  end
  local names = {}
  local seen = {}

  local function consider(candidate)
    if candidate ~= path and parent(candidate) == path then
      local name = candidate:match("([^/]+)$")
      if not seen[name] then
        seen[name] = true
        names[#names + 1] = name
      end
    end
  end

  for candidate in pairs(self.directories) do
    consider(candidate)
  end
  for candidate in pairs(self.files) do
    consider(candidate)
  end
  table.sort(names)
  return names
end

function MemoryFilesystem:removeTree(path)
  self.files[path] = nil
  self.directories[path] = nil
  for candidate in pairs(self.files) do
    if hasPrefix(candidate, path) then
      self.files[candidate] = nil
    end
  end
  for candidate in pairs(self.directories) do
    if hasPrefix(candidate, path) then
      self.directories[candidate] = nil
    end
  end
  self.events[#self.events + 1] = { operation = "remove", path = path }
  return true
end

function MemoryFilesystem:rename(source, destination)
  if self.renameFailure then
    local message = self.renameFailure(source, destination)
    if message then
      return nil, message
    end
  end
  if not self:info(source) then
    return nil, "source does not exist"
  end
  if self:info(destination) then
    return nil, "destination already exists"
  end
  if not self.directories[parent(destination)] then
    return nil, "destination parent does not exist"
  end

  local movedDirectories = {}
  local movedFiles = {}
  for candidate in pairs(self.directories) do
    if hasPrefix(candidate, source) then
      movedDirectories[#movedDirectories + 1] = candidate
    end
  end
  for candidate in pairs(self.files) do
    if hasPrefix(candidate, source) then
      movedFiles[#movedFiles + 1] = candidate
    end
  end

  for _, candidate in ipairs(movedDirectories) do
    self.directories[candidate] = nil
  end
  for _, candidate in ipairs(movedFiles) do
    local data = self.files[candidate]
    self.files[candidate] = nil
    local suffix = candidate:sub(#source + 1)
    self.files[destination .. suffix] = data
  end
  for _, candidate in ipairs(movedDirectories) do
    local suffix = candidate:sub(#source + 1)
    self.directories[destination .. suffix] = true
  end

  self.events[#self.events + 1] = {
    operation = "rename",
    source = source,
    destination = destination,
  }
  return true
end

return MemoryFilesystem
