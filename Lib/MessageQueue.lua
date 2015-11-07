local MAJOR, MINOR = "MessageQueue", 1
local APkg = Apollo.GetPackage(MAJOR)

-- See if there is already a version of our package loaded.
-- If there is a package loaded with the same or higher version,
-- then exit, as we will use that one.
if APkg and (APkg.nVersion or 0) >= MINOR then
  return
end

-- Package Definition
local MessageQueue = {}

---------------------------------------------------------------------------------------------------
-- Queue Module Initialization
---------------------------------------------------------------------------------------------------
function MessageQueue:new()
  local o = {first = 0, last = -1}
  setmetatable(o, self)
  self.__index = self
  return o
end

---------------------------------------------------------------------------------------------------
-- Queue Push and Pop
---------------------------------------------------------------------------------------------------
function MessageQueue:Push (value)
  local last = self.last + 1
  
  self.last = last
  self[last] = value
end
    
function MessageQueue:Pop()
  local first = self.first
  
  if first > self.last then
    error("MessageQueue: Cannot pop from an empty queue!") 
  end
  
  local value = self[first]
  
  self[first] = nil
  self.first = first + 1
  
  return value
end

function MessageQueue:GetSize()
  local length = self.last - self.first + 1
  
  return length
end

-- Package Registration
function MessageQueue:Initialize()
  Apollo.RegisterPackage(self, MAJOR, MINOR, {})
end

MessageQueue:Initialize()