require "ICCommLib"
require "ICComm"

local MAJOR, MINOR = "Communicator", 1
local APkg = Apollo.GetPackage(MAJOR)

if APkg and (APkg.nVersion or 0) >= MINOR then
  return
end

local Communicator = APkg and APkg.tPackage or {}
local Message = Apollo.GetPackage("Message").tPackage
local MessageQueue = Apollo.GetPackage("MessageQueue").tPackage

---------------------------------------------------------------------------------------------------
-- Local Functions
---------------------------------------------------------------------------------------------------
local function split(strString, strSeparator)
  if strSeparator == nil then
    strSeparator = "%s"
  end
  
  local tResult = {}
  local nIndex = 1
  local strPattern = string.format("([^%s]+)%s", strSeparator, strSeparator)
  
  for strMatch in strString:gmatch(strPattern) do
    tResult[nIndex] = strMatch
    nIndex = nIndex + 1
  end
  
  return unpack(tResult)
end

---------------------------------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------------------------------
Communicator.Error_UnimplementedProtocol = 1
Communicator.Error_UnimplementedCommand = 2
Communicator.Error_RequestTimedOut = 3
Communicator.Debug_Errors = 1
Communicator.Debug_Comm = 2
Communicator.Debug_Access = 3
Communicator.TTL_Trait = 120
Communicator.TTL_Version = 300
Communicator.TTL_Flood = 30
Communicator.TTL_Channel = 60
Communicator.TTL_Packet = 15
Communicator.TTL_GetAll = 120
Communicator.TTL_CacheDie = 604800
Communicator.Trait_Name = "full_name"
Communicator.Trait_NameAndTitle = "title"
Communicator.Trait_RPFlag = "rp_flag"
Communicator.Trait_RPState = "rp_state"
Communicator.Trait_Description = "description"
Communicator.Trait_Biography = "bio"
Communicator.Trait_All = "getall"

-- This is the constructor of Communicator.
-- We use this to create a new instance and set the initial state
-- of the Addon.
function Communicator:new(o)
  o = o or {}
  
  setmetatable(o, self)
  
  self.__index = self
  
  return o
end

-- This function is called by the Client when the Addon needs to be loaded.
-- When this is called, we will initialize our environment and register
-- all event-handlers as well as setting up our DataStructures.
function Communicator:OnLoad()
  -- Initialize our internal state
  self.tApiProtocolHandlers = {}
  self.tLocalTraits = {}
  self.tOutGoingRequests = {}
  self.tFloodPrevent = {}
  self.tCachedPlayerData = {}
  self.tPendingPlayerTraitRequests = {}
  self.tCachedPlayerChannels = {}
  self.bTimeoutRunning = false
  self.nSequenceCounter = 0
  self.nDebugLevel = 3
  self.qPendingMessages = MessageQueue:new()
  self.kstrRPStateStrings = {
    "In-Character, Not Available for RP",
    "Available for RP",
    "In-Character, Available for RP",
    "In a Private Scene (Temporarily OOC)",
    "In a Private Scene",
    "In an Open Scene (Temporarily OOC)",
    "In an Open Scene" 
  }
  self.strPlayerName = nil
  
  -- Register our event handlers for the timers.
  Apollo.RegisterTimerHandler("Communicator_Timeout", "OnTimerTimeout", self)
  Apollo.RegisterTimerHandler("Communicator_TimeoutShutdown", "OnTimerTimeoutShutdown", self)
  Apollo.RegisterTimerHandler("Communicator_Queue", "OnTimerProcessMessageQueue", self)
  Apollo.RegisterTimerHandler("Communicator_QueueShutdown", "OnTimerQueueShutdown", self)
  Apollo.RegisterTimerHandler("Communicator_Setup", "OnTimerSetup", self)
  Apollo.RegisterTimerHandler("Communicator_TraitQueue", "OnTimerTraitQueue", self)
  Apollo.RegisterTimerHandler("Communicator_CleanupCache", "OnTimerCleanupCache", self)
  
  -- Create the relevant timers
  Apollo.CreateTimer("Communicator_Setup", 1, false)
  Apollo.CreateTimer("Communicator_CleanupCache", 60, true)
end

-- This is the initializer of the Communicator Addon.
-- We use this function to register ourself in the Client as a new Addon
-- that needs to be maintained.
function Communicator:Init()
  local bHasConfigureFunction = false
  local strConfigureButtonText = ""
  local tDependencies = {
    "Lib:dkJSON-2.5"
  }
  
  Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

-- This function is called by the Client whenever the Addon needs to save all the data.
-- Because this is character or Realm based, we need to check the eLevel.
function Communicator:OnSave(eLevel)
  if eLevel == GameLib.CodeEnumAddonSaveLevel.Character then
    return { tLocalData = self.tLocalTraits }
  elseif eLevel == GameLib.CodeEnumAddonSavelevel.Realm then
    return { tCachedData = self.tCachedPlayerData }
  else
    return nil
  end
end

-- This function is called by the Client whenever the Addon needs to load all the data.
-- Because our data structure depends on the eLevel, we need to check the cases.
function Communicator:OnRestore(eLevel, tData)
  if tData ~= nil and eLevel == GameLib.CodeEnumAddonSaveLevel.Character then
    self.tLocalTraits = tData.tLocalData or {}
  elseif tData ~= nil and eLevel == GameLib.CodeEnumAddonSaveLevel.Realm then
    self.tCachedPlayerData = tData.tCachedData or {}
  end
end

-- This function is called every time the Timer "Communicator_Setup" has finished.
-- This function will then check whether our player character has been loaded into
-- the game world and fetch the name.
-- Should the character not be loaded yet, then we fire the timer up again and wait
-- a bit longer before trying to get the name again.
-- If the name can be loaded, then we also set up the ICComm channel for communication.
function Communicator:OnTimerSetup()
  if GameLib.GetPlayerUnit() == nil then
    Apollo.CreateTimer("Communicator_Setup", 1, false)
    return
  end
  
  -- Configure the ICCommLib channel for our Addon.
  self:ChannelForPlayer()
end

-- Constructs a new Message structure, that represents a reply on the provided message.
-- The tPayload parameter will be set as the payload of the response.
function Communicator:Reply(mMessage, tPayload)
  local mReply = Message:new()
  
  mReply:SetProtocolVersion(mMessage:GetProtocolVersion())
  mReply:SetSequence(mMessage:GetSequence())
  mReply:SetAddonProtocol(mMessage:GetAddonProtocol())
  mReply:SetType(mMessage:GetType())
  mReply:SetPayload(tPayload)
  mReply:SetDestination(mMessage:GetOrigin())
  mReply:SetCommand(mMessage:GetCommand())
  mReply:SetOrigin(mMessage:GetDestination())
  
  return mReply
end

-- Returns the name to be used as Origin for any message being send out by Communicator.
-- If the current player unit cannot be loaded, then nil will be returned instead.
function Communicator:GetOriginName()
  local unitPlayer = GameLib.GetPlayerUnit()
  
  if unitPlayer ~= nil then
    self.strPlayerName = unitPlayer:GetName()
  end
  
  return self.strPlayerName
end

-- Sets the debug level for Communicator, controlling the output level of the Library.
function Communicator:SetDebugLevel(eLevel)
  self.nDebugLevel = eLevel
end

function Communicator:ValueOfBit(p)
  return 2 ^ (p - 1)
end

function Communicator:HasBitFlag(x, p)
  local np = self:ValueOfBit(p)
  return x % (np + np) >= np
end

function Communicator:SetBitFlag(x, p, b)
  local np = self:ValueOfBit(p)
  
  if(b) then
    return self:HasBitFlag(x, p) and x or x + np
  else
    return self:HasBitFlag(x, p) and x - np or x
  end
end

-- Writes the provided log message into the chat, using a controlled structure.
-- The provided level is used to check whether we're supposed to actually write the 
-- log message.
function Communicator:Log(nLevel, strLog)
  if nLevel > self.nDebugLevel then
    return 
  end
  
  Print("Communicator: " .. strLog)
end

function Communicator:FlagsToString(nState)
  return self.kstrRPStateStrings[nState] or "Not Available for RP"
end

function Communicator:EscapePattern(strPattern)
  return strPattern:gsub("(%W)", "%%%1")
end

function Communicator:TruncateString(strText, nLength)
  if(strText == nil) then
    return nil
  end
  
  if strText:len() <= nLength then
    return strText 
  end
  
  local strResult = strText:sub(1, nLength)
  local nSpacePos = strResult:find(" ", -1)
  
  if nSpacePos ~= nil then
    strResult = strResult:sub(1, nSpacePos - 1) .. "..."
  end
  
  return strResult
end

-- Returns the provided trait of the specified target.
-- If the target is not yet stored in the Cache, we fetch it and return it
-- when it becomes available.
-- If the call fails, nil is returned instead.
function Communicator:GetTrait(strTarget, strTrait)
  local strResult = nil
  
  if strTrait == Communicator.Trait_Name then
    strResult = self:FetchTrait(strTarget, Communicator.Trait_Name) or strTarget
  elseif strTrait == Communicator.Trait_NameAndTitle then
    local strName = self:FetchTrait(strTarget, Communicator.Trait_Name)
    strResult = self:FetchTrait(strTarget, Communicator.Trait_NameAndTitle)
    
    if strResult == nil then
      strResult = strName
    else
      local nStart,nEnd = strResult:find("#name#")
      
      if nStart ~= nil then
        strResult = strResult:gsub("#name#", self:EscapePattern(strName or strTarget))
      else
        strResult = strResult.." "..(strName or strTarget)
      end
    end
  elseif strTrait == Communicator.Trait_Description then
    strResult = self:FetchTrait(strTarget, Communicator.Trait_Description)
   
    if strResult ~= nil then
      strResult = self:TruncateString(strResult, Communicator.MaxLength)
    end
  elseif strTrait == Communicator.Trait_RPState then
    local rpFlags = self:FetchTrait(strTarget, Communicator.Trait_RPState) or 0
    strResult = self:FlagsToString(rpFlags)
  elseif strTrait == Communicator.Trait_Biography then
    strResult = self:FetchTrait(strTarget, Communicator.Trait_Biography)
  else
    strResult = self:FetchTrait(strTarget, strTrait)
  end
  
  return strResult
end

function Communicator:SetRPFlag(flag, bSet)
  local nState, nRevision = self:GetLocalTrait(Communicator.Trait_RPFlag)
  nState = self:SetBitFlag(flag, bSet)
  self:SetLocalTrait(Communicator.Trait_RPFlag, nState)
end

-- This function is called on a regular basis and processes the messages currently stored in
-- the TraitQueue.
function Communicator:OnTimerTraitQueue()
  -- Loop over every message in the Queue.
  for strTarget, aRequests in pairs(self.tPendingPlayerTraitRequests) do
    self:Log(Communicator.Debug_Comm, "Sending: " .. table.getn(aRequests) .. " queued trait requests to " .. strTarget)
    
    local mMessage = Message:new()
    
    -- Construct the message using the information in the Queue.
    mMessage:SetDestination(strTarget)
    mMessage:SetCommand("get")
    mMessage:SetPayload(aRequests)
    
    -- Send the message to the target, and clear it from the Queue.
    self:SendMessage(mMessage)
    self.tPendingPlayerTraitRequests[strTarget] = nil
  end
end

-- Fetches the provided trait from the specified target.
-- The information is read from the local cache, but when the cache does not contain any
-- information, a request is made to the target to provide the information.
function Communicator:FetchTrait(strTarget, strTraitName)
  -- If no target is provided, or we're fetching our own traits, then check
  -- the localTraits cache for the information and return it when avaialble.
  if strTarget == nil or strTarget == self:GetOriginName() then
    local tTrait = self.tLocalTraits[strTraitName] or {}
    self:Log(Communicator.Debug_Access, string.format("Fetching own %s: (%d) %s", strTraitName, tTrait.revision or 0, tostring(tTrait.data)))
    return tTrait.data, tTrait.revision
  else
    -- Check the local cached player data for the information
    local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
    local tTrait = tPlayerTraits[strTraitName] or {}
    local nTTL = Communicator.TTL_Trait
    
    self:Log(Communicator.Debug_Access, string.format("Fetching %s's %s: (%d) %s", strTarget, strTraitName, tTrait.revision or 0, tostring(tTrait.data)))
    
    -- Check if the TTL is set correctly, and do so if not.    
    if (tTrait.revision or 0) == 0 then
      nTTL = 10 
    end
    
    -- If the trait could not be found, or it has exceeded it's TTL, then
    -- prepare to request the information again from the target.
    -- We do this by setting the query in the request queue and fire a timer to
    -- process it in the background.
    if tTrait == nil or (os.time() - (tTrait.time or 0)) > nTTL then
      tTrait.time = os.time()
      tPlayerTraits[strTraitName] = tTrait
      self.tCachedPlayerData[strTarget] = tPlayerTraits
      
      local tPendingPlayerQuery = self.tPendingPlayerTraitRequests[strTarget] or {}
      local tRequest = { trait = strTraitName, revision = tTrait.revision or 0 }
      
    self:Log(Communicator.Debug_Access, string.format("Building up query to retrieve %s's %s:", strTarget, strTraitName))
      table.insert(tPendingPlayerQuery, tRequest)
      self.tPendingPlayerTraitRequests[strTarget] = tPendingPlayerQuery
      Apollo.CreateTimer("Communicator_TraitQueue", 1, false)
    end
    
    return tTrait.data, tTrait.revision
  end
end

-- Caches the provided trait, with it's value and revision in the cache, using the name of
-- the target as identifier.
function Communicator:CacheTrait(strTarget, strTrait, data, nRevision)
  if strTarget == nil or strTarget == self:GetOriginName() then
    self.tLocalTraits[strTrait] = {
      data = data,
      revision = nRevision 
    }
    self:Log(Communicator.Debug_Access, string.format("Caching own %s: (%d) %s", strTrait, nRevision or 0, tostring(data)))
    Event_FireGenericEvent("Communicator_TraitChanged", { player = self:GetOriginName(), trait = strTrait, data = data, revision = nRevision })
  else
    local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
    
    if nRevision ~= 0 and tPlayerTraits.revision == nRevision then
      tPlayerTraits.time = os.time()
      return
    end
    
    if data == nil then
      return
    end
    
    tPlayerTraits[strTrait] = { data = data, revision = nRevision, time = os.time() }
    self.tCachedPlayerData[strTarget] = tPlayerTraits
    self:Log(Communicator.Debug_Access, string.format("Caching %s's %s: (%d) %s", strTarget, strTrait, nRevision or 0, tostring(data)))
    Event_FireGenericEvent("Communicator_TraitChanged", { player = strTarget, trait = strTrait, data = data, revision = nRevision })
  end
end  

function Communicator:SetLocalTrait(strTrait, data)
  local value, revision = self:FetchTrait(nil, strTrait)
  
  if value == data then
    return
  end
  
  if strTrait == Communicator.Trait_RPState or strTrait == Communicator.Trait_RPFlag then
    revision = 0 
  else
    revision = (revision or 0) + 1 
  end
  
  self:CacheTrait(nil, strTrait, data, revision)
end

function Communicator:GetLocalTrait(strTrait)
  return self:FetchTrait(nil, strTrait)
end

function Communicator:QueryVersion(strTarget)
  if strTarget == nil or strTarget == self:GetOriginName() then
    local aProtocols = {}
    
    for strAddonProtocol, _ in pairs(self.tApiProtocolHandlers) do
      table.insert(aProtocols, strAddonProtocol)
    end
    
    return Communicator.Version, aProtocols
  end
  
  local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
  local tVersionInfo = tPlayerTraits["__rpVersion"] or {}
  local nLastTime = self:TimeSinceLastAddonProtocolCommand(strTarget, nil, "version")
  
  if nLastTime < Communicator.TTL_Version then
    return tVersionInfo.version, tVersionInfo.addons
  end
  
  self:MarkAddonProtocolCommand(strTarget, nil, "version")
  self:Log(Communicator.Debug_Access, string.format("Fetching %s's version", strTarget))
  
  if tVersionInfo.version == nil or (os.time() - (tVersionInfo.time or 0) > Communicator.TTL_Version) then
    local mMessage = Message:new()
    
    mMessage:SetDestination(strTarget)
    mMessage:SetType(Message.CodeEnumType.Request)
    mMessage:SetCommand("version")
    mMessage:SetPayload({""})
    
    self:SendMessage(mMessage)
  end
  
  return tVersionInfo.version, tVersionInfo.addons
end

function Communicator:StoreVersion(strTarget, strVersion, aProtocols)
  if strTarget == nil or strVersion == nil then
    return 
  end
  
  local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
  tPlayerTraits["__rpVersion"] = { version = strVersion, protocols = aProtocols, time = os.time() }
  self.tCachedPlayerData[strTarget] = tPlayerTraits
  
  self:Log(Communicator.Debug_Access, string.format("Storing %s's version: %s", strTarget, strVersion))
  Event_FireGenericEvent("Communicator_VersionUpdated", { player = strTarget, version = strVersion, protocols = aProtocols })
end

function Communicator:GetAllTraits(strTarget)
  local tPlayerTraits = self.tCachedPlayerData[strTarget] or {}
  self:Log(Communicator.Debug_Access, string.format("Fetching %s's full trait set (version: %s)", strTarget, Communicator.Version))
  
  if(self:TimeSinceLastAddonProtocolCommand(strTarget, nil, Communicator.Trait_All) > Communicator.TTL_GetAll) then
    local mMessage = Message:new()
    
    mMessage:SetDestination(strTarget)
    mMessage:SetType(Message.CodeEnumType.Request)
    mMessage:SetCommand(Communicator.Trait_All)
    
    self:SendMessage(mMessage)
    self:MarkAddonProtocolCommand(strTarget, nil, Communicator.Trait_All)
  end
  
  local tResult = {}
  
  for key, data in pairs(tPlayerTraits) do
    if key:sub(1,2) ~= "__" then
      tResult[key] = data.data
    end
  end
  
  return tResult
end

function Communicator:StoreAllTraits(strTarget, tPlayerTraits)
  self:Log(Communicator.Debug_Access, string.format("Storing new trait cache for %s", strTarget))
  self.tCachedPlayerData[strTarget] = tPlayerTraits
  
  local tResult = {}
  
  for key, data in pairs(tPlayerTraits) do
    if(key:sub(1,2) ~= "__") then
      tResult[key] = data.data
    end
  end
  
  Event_FireGenericEvent("Communicator_PlayerUpdated", { player = strTarget, traits = tResult })
end

function Communicator:TimeSinceLastAddonProtocolCommand(strTarget, strAddonProtocol, strCommand)
  local strCommandId = string.format("%s:%s:%s", strTarget, strAddonProtocol or "base", strCommand)
  local nLastTime = self.tFloodPrevent[strCommandId] or 0
  
  return (os.time() - nLastTime)
end

function Communicator:MarkAddonProtocolCommand(strTarget, strAddonProtocol, strCommand)
  local strCommandId = string.format("%s:%s:%s", strTarget, strAddonProtocol or "base", strCommand)
  self.tFloodPrevent[strCommandId] = os.time()
end
  
function Communicator:OnSyncMessageReceived(channel, strMessage, idMessage)
  local mMessage = Message:new()
  
  mMessage:Deserialize(strMessage)
  
  if tonumber(mMessage:GetProtocolVersion() or 0) > Message.ProtocolVersion then
    Print("Communicator: Warning :: Received packet for unrecognized version " .. mMessage:GetProtocolVersion())
    return
  end
  
  if mMessage:GetDestination() == self:GetOriginName() then
    self:ProcessMessage(mMessage)
  end
end

-- Processes the provided message, parsing the contents and taking the required
-- action based on the data stored inside.
function Communicator:ProcessMessage(mMessage)
  self:Log(Communicator.Debug_Comm, "Processing Message")
  
  -- Check if we're dealing with an error message.
  if mMessage:GetType() == Message.CodeEnumType.Error then
    local tData = self.tOutGoingRequests[mMessage:GetSequence()] or {}
    
    if tData.handler then
      tData.handler(mMessage)
      self.tOutGoingRequests[mMessage:GetSequence()] = nil
      return
    end
  end
  
  -- If no AddonProtocol has been defined for the message, then look at the data
  -- that is being provided and try to parse it.
  if mMessage:GetAddonProtocol() == nil then
    local eType = mMessage:GetType()
    local tPayload = mMessage:GetPayload() or {}
  
    -- This is something for Communicator itself.
    if eType == Message.CodeEnumType.Request then
      if mMessage:GetCommand() == "get" then
        local aReplies = {}
        
        for _, tTrait in ipairs(tPayload) do
          local data, revision = self:FetchTrait(nil, tTrait.trait or "")
          
          if data ~= nil then
            local tResponse = { trait = tTrait.trait, revision = revision }
            
            if tPayload.revision == 0 or revision ~= tPayload.revision then
              tResponse.data = data
            end
            
            table.insert(aReplies, tResponse)
          else
            table.insert(aReplies, { trait = tTrait.trait, revision = 0 })
          end
        end
        
        local mReply = self:Reply(mMessage, aReplies)
        self:SendMessage(mReply)
      elseif mMessage:GetCommand() == "version" then
        local aProtocols = {}
        
        for strAddonProtocol, _ in pairs(self.tApiProtocolHandlers) do
          table.insert(aProtocols, strAddonProtocol)
        end
        
        local mReply = self:Reply(mMessage, { version = Communicator.Version, protocols = aProtocols })
        self:SendMessage(mReply)
      elseif mMessage:GetCommand() == Communicator.Trait_All then
        local mReply = self:Reply(mMessage, self.tLocalTraits)
        self:SendMessage(mReply)
      else
        local mReply = self:Reply(mMessage, { error = self.Error_UnimplementedCommand })
        mReply:SetType(Message.CodeEnumType.Error)
        self:SendMessage(mReply)
      end
    elseif eType == Message.CodeEnumType.Reply then
      if mMessage:GetCommand() == "get" then
        for _, tTrait in ipairs(tPayload) do
          self:CacheTrait(mMessage:GetOrigin(), tTrait.trait, tTrait.data, tTrait.revision)
        end
      elseif mMessage:GetCommand() == "version" then
        self:StoreVersion(mMessage:GetOrigin(), tPayload.version, tPayload.protocols)
      elseif mMessage:GetCommand() == Communicator.Trait_All then
        self:StoreAllTraits(mMessage:GetOrigin(), tPayload)
      end
    elseif eType == Message.CodeEnumType.Error then
      if(mMessage:GetCommand() == Communicator.Trait_All) then
        Event_FireGenericEvent("Communicator_PlayerUpdated", { player = mMessage:GetOrigin(), unsupported = true })
      end
    end
  else
    local aAddon = self.tApiProtocolHandlers[mMessage:GetAddonProtocol()]
    
    if aAddon ~= nil or table.getn(aAddon) == 0 then
      for _, fHandler in ipairs(aAddon) do
        fHandler(mMessage)
      end
    elseif mMessage:GetType() == Message.CodeEnumType.Request then
      local mError = self:Reply(mMessage, { type = Communicator.Error_UnimplementedProtocol })
      mError:SetType(Message.CodeEnumType.Error)
      self:SendMessage(mError)
    end
  end
    
  if mMessage:GetType() == Message.CodeEnumType.Reply or mMessage:GetType() == Message.CodeEnumType.Error then
    self.tOutGoingRequests[mMessage:GetSequence()] = nil
  end
end

function Communicator:SendMessage(mMessage, fCallback)
  if mMessage:GetDestination() == self:GetOriginName() then
    return
  end
  
  if mMessage:GetType() ~= Message.CodeEnumType.Error and mMessage:GetType() ~= Message.CodeEnumType.Reply then
    self.nSequenceCounter = tonumber(self.nSequenceCounter or 0) + 1
    mMessage:SetSequence(self.nSequenceCounter)
  end
  
  self.tOutGoingRequests[mMessage:GetSequence()] = { message = mMessage, handler = fCallback, time = os.time() }
  self.qPendingMessages:Push(mMessage)
  
  if not self.bQueueProcessRunning then
    self.bQueueProcessRunning = true
    Apollo.CreateTimer("Communicator_Queue", 0.5, true)
  end
end

-- Configures the internal ICCommChannel to be used for communication of the Addon.
-- If the channel is already configured, then simply return it, or configure it.
function Communicator:ChannelForPlayer()
  if self.chnCommunicator == nil then
    self.chnCommunicator = ICCommLib.JoinChannel("Communicator", ICCommLib.CodeEnumICCommChannelType.Global)
    self.chnCommunicator:SetJoinResultFunction("OnSyncChannelJoined", self)
    self.chnCommunicator:IsReady()
    self.chnCommunicator:SetReceivedMessageFunction("OnSyncMessageReceived", self)
  end
  
  return self.chnCommunicator
end
    
function Communicator:OnTimerQueueShutdown()
  Apollo.StopTimer("Communicator_Queue")
  self.bQueueProcessRunning = false
end

function Communicator:OnTimerProcessMessageQueue()
  if self.qPendingMessages:GetSize() == 0 then
    Apollo.CreateTimer("Communicator_QueueShutDown", 0.1, false)
    return
  end
  
  local mMessage = self.qPendingMessages:Pop()
  local channel = self:ChannelForPlayer()
  
  if channel.SendPrivateMessage ~= nil then
    channel:SendPrivateMessage(mMessage:GetDestination(), mMessage:Serialize())
  else
    channel:SendMessage(mMessage:Serialize())
  end
  
  if not self.bTimeoutRunning then
    self.bTimeoutRunning = true
    Apollo.CreateTimer("Communicator_Timeout", 15, true)
  end
end
    
function Communicator:OnTimerTimeoutShutdown()
  Apollo.StopTimer("Communicator_Timeout")
  self.bTimeoutRunning = false
end

function Communicator:OnTimerTimeout()
  local nNow = os.time()
  local nOutgoingCount = 0
  
  for nSequence, tData in pairs(self.tOutGoingRequests) do
    if (nNow - tData.time) > Communicator.TTL_Packet then
      local tPayload = {
        error = Communicator.Error_RequestTimedOut, 
        destination = tData.message:GetDestination(),
        localError = true 
      }
      local mError = self:Reply(tData.message, tPayload)
      
      mError:SetType(Message.CodeEnumType.Error)
      
      self:ProcessMessage(mError)
      self.tOutGoingRequests[nSequence] = nil
    else
      nOutgoingCount = nOutgoingCount + 1
    end
  end
  
  for strCommandId, nLastTime in pairs(self.tFloodPrevent) do
    if (nNow - nLastTime) > Communicator.TTL_Flood then
      self.tFloodPrevent[strCommandId] = nil
    end
  end
  
  for strPlayerName, tChannelRecord in pairs(self.tCachedPlayerChannels) do
    if (nNow - tChannelRecord.time or 0) > Communicator.TTL_Channel then
      self.tCachedPlayerChannels[strPlayerName] = nil
    end
  end
  
  if(nOutgoingCount == 0) then
    Apollo.CreateTimer("Communicator_TimeoutShutdown", 0.1, false)
  end
end

function Communicator:OnTimerCleanupCache()
  local nNow = os.time()
  
  for strPlayerName, tRecord in pairs(self.tCachedPlayerData) do
    for strParam, tTrait in pairs(tRecord) do
      if(nNow - tTrait.time > Communicator.TTL_CacheDie) then
        tRecord[strParam] = nil
      end
    end
    
    local nCount = 0
    
    for strParam, tTrait in pairs(tRecord) do
      nCount = nCount + 1
    end
    
    if(nCount == 0) then
      self.tCachedPlayerData[strPlayerName] = nil
    end
  end
end

function Communicator:Stats()
  local nLocalTraits = 0
  local nPlayers = 0
  local nCachedTraits = 0
  
  for strTrait, tRecord in pairs(self.tLocalTraits) do
    nLocalTraits = nLocalTraits + 1
  end
  
  for strPlayer, tRecord in pairs(self.tCachedPlayerData) do
    nPlayers = nPlayers + 1
    
    for strParam, tValue in pairs(tRecord) do
      nCachedTraits = nCachedTraits + 1
    end
  end
  
  return nLocalTraits, nCachedTraits, nPlayers
end

function Communicator:GetCachedPlayerList()
  local tCachedPlayers = {}
 
  for strPlayerName, _ in pairs(self.tCachedPlayerData) do
    table.insert(tCachedPlayers, strPlayerName)
  end
  
  return tCachedPlayers
end

function Communicator:ClearCachedPlayerList()
  for strPlayerName, _ in pairs(self.tCachedPlayerData) do
    if strPlayerName ~= self:GetOriginName() then
      self.tCachedPlayerData[strPlayerName] = nil
    end
  end
end

function Communicator:CacheAsTable()
  return { locaData = self.tLocalTraits, cachedData = self.tCachedPlayerData }
end

function Communicator:LoadFromTable(tData)
  self.tLocalTraits = tData.localData or {}
  self.tCachedPlayerData = tData.cachedData or {}
  self:OnTimerCleanupCache()
end

function Communicator:RegisterAddonProtocolHandler(strAddonProtocol, fHandler)
  local aHandlers = self.tApiProtocolHandlers[strAddonProtocol] or {}
  table.insert(aHandlers, fHandler)
  self.tApiProtocolHandlers[strAddonProtocol] = aHandlers
end

---------------------------------------------------------------------------------------------------
-- Package Registration
---------------------------------------------------------------------------------------------------
function Communicator:Initialize()
  Apollo.RegisterPackage(self, MAJOR, MINOR, { })
end

Communicator:Initialize()