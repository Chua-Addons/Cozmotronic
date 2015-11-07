require "Window"
require "ICCommLib"
require "ICComm"

local Cozmotronic = {}
local Communicator = {}

-- The constructor of our Addon.
-- We use this to create a new instance of the Addon and configure 
-- the initial settings.
function Cozmotronic:new(o)
  o = o or {}
  
  setmetatable(o, self)
  
  self.__index = self
  
  -- Configure the initial state of the Addon
  o.bEnabled = true
  
  return o
end

-- The initializer of our Addon.
-- We use this to inform the client that we have a new Addon and want to register it
-- for usage.
function Cozmotronic:Init()
  local bHasConfigureFunction = true
  local strConfigureButtonText = "Cozmotronic"
  local tDependencies = {
    "Communicator"
  }
  
  Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

-- This function is called by the Client when the Addon has been registered and is ready
-- to be loaded. We will use this to trigger the XML Load and build up the forms.
function Cozmotronic:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("Cozmotronic.xml")
  self.xmlDoc:RegisterCallback("OnDocumentLoaded", self)
  
  -- Load the Communicator Package
  Communicator = Apollo.GetPackage("Communicator")
  
  if Communicator then
    self.Communicator = Communicator.tPackage:new()
  else
    Apollo.AddAddonErrorText(self, "Could not load Communicator for some reason.")
  end
end

-- This function is called whenever the Addon has finished loading it's XML document.
-- When this has completed, we will attempt to load the forms and register the required
-- callbacks to make the Addon functional.
function Cozmotronic:OnDocumentLoaded()
  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
    -- Set up the main window of our Addon.
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "wndMain", nil, self)
    
    if self.wndMain == nil then
      Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
      return
    end
    
    self.wndMain:Show(false, true)
    
    -- Set up our event handlers
    Apollo.RegisterSlashCommand("cozmo", "OnSlashCommand", self)
    Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
    Apollo.RegisterEventHandler("ToggleCozmotronic", "OnToggleCozmotronic", self)
  else
    error("Failed to load XML")    
  end
end

-- This function is called whenever the user types /cozmo.
-- We will use this to properly display the main window.
function Cozmotronic:OnSlashCommand(strCommand, strArgs)
  self.wndMain:Show(true)
end

-- This function is called whenever the Interface MenuList has finished loaded and
-- the relevant event is called. We use this opportunity to add ourselves to the
-- list as well with a small button.
function Cozmotronic:OnInterfaceMenuListHasLoaded()
  local strEvent = "InterfaceMenuList_NewAddOn"
  local strAddon = "Cozmotronic"
  local tParams = { "ToggleCozmotronic", "", "charactercreate:sprCharC_Finalize_RaceChua" }
  
  Event_FireGenericEvent(strEvent, strAddon, tParams)
  self:UpdateInterfaceMenuAlerts()  
end

-- This function is called whenever the user clicks on the Cozmotronic button
-- in the Interface list. We use this to either enable or disable the Addon.
-- This function is called because we raise the event "ToggleCozmotronic", which is
-- caught by our Addon using this function because we registered an EventHandler for it.
function Cozmotronic:OnToggleCozmotronic()  
  self.bEnabled = not self.bEnabled
  self:UpdateInterfaceMenuAlerts()
end

-- This function will toggle the state of the button in the InterfaceMenuList.
-- The button will  be glowing when the Addon is enabled, and dark when the
-- Addon is disabled.
function Cozmotronic:UpdateInterfaceMenuAlerts()
  local strEvent = "InterfaceMenuList_AlertAddOn"
  local strAddon = "Cozmotronic"
  local strCredits = "by Olivar Nax@Jabbit\n"
  local strStatus = self.bEnabled and "Enabled" or "Disabled"
  local tParams = { self.bEnabled, strCredits..strStatus, 0 }
  
  Event_FireGenericEvent(strEvent, strAddon, tParams)
end

-- This function is called by the Client whenever the Addon needs to save the data.
-- Because the settings can vary from character, to realm, to account, we need to 
-- check the level and return the correct data based on the level.
function Cozmotronic:OnSave(eLevel)
  -- Realm data
  if eLevel == GameLib.CodeEnumAddonSaveLevel.Realm then
    return nil
  end
  
  -- Account data
  if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
    return nil
  end
  
  -- Character data
  if eLevel == GameLib.CodeEnumAddonSaveLevel.Character then
    local tData = {
      bEnabled = self.bEnabled
    }
    
    return tData
  end
  
  -- General data
  if eLevel == GameLib.CodeEnumAddonSaveLevel.General then
    return nil
  end
end

-- This function is called by the Client whenever the Addon needs to restore the data.
-- Because the settings can vary from character, to realm, to account, we need to check
-- the eLevel and react accordingly, as the data structures will differ.
function Cozmotronic:OnLoad(eLevel, tData)
  -- Realm data
  if eLevel == GameLib.CodeEnumAddonSaveLevel.Realm then
    return
  end
  
  -- Account data
  if eLevel == GameLib.CodeEnumAddonSaveLevel.Account then
    return
  end
  
  -- Character data
  if eLevel == GameLib.CodeEnumAddonSaveLevel.Character then
    self.bEnabled = tData.bEnabled or true
  end
  
  -- General data
  if eLevel == GameLib.CodeEnumAddonSaveLevel.General then
    return
  end
end

function Cozmotronic:OnConfigure()
  Print("Configuration not implemented yet.")
end
-----------------------------------------------------------------------------------------------
-- Cozmotronic Instance
-----------------------------------------------------------------------------------------------
local CozmotronicInst = Cozmotronic:new()
CozmotronicInst:Init()