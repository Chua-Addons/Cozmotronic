require "Window"
require "GameLib"
require "Unit"
require "ICCommLib"
require "ICComm"

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local ktNameplateOptions = {
  nXoffset = 0,
  nYoffset = -50,
  bShowMyNameplate = true,
  bShowNames = true,
  bShowTitles = true,
  bScaleNameplates = false,
  nNameplateDistance = 50,
  nAnchor = 1,
  bShowTargetNameplate = false,
}

local ktStateColors = {
  [0] = "ffffffff", -- white
  [1] = "ffffff00", --yellow
  [2] = "ff0000ff", --blue
  [3] = "ff00ff00", --green
  [4] = "ffff0000", --red
  [5] = "ff800080", --purple
  [6] = "ff00ffff", --cyan
  [7] = "ffff00ff", --magenta
}

local ktStyles = {
  { tag = "h1", font = "CRB_Interface14_BBO", color = "FF00FA9A", align = "Center" },
  { tag = "h2", font = "CRB_Interface12_BO", color = "FF00FFFF", align = "Left" },
  { tag = "h3", font = "CRB_Interface12_I", color = "FF00FFFF", align = "Left" },
  { tag = "p", font = "CRB_Interface12", color = "FF00FFFF", align = "Left"},
  { tag = "li", font = "CRB_Interface12", color = "FF00FFFF", align = "Left", bullet = "●", indent = "  " },
  { tag = "alien", font = "CRB_AlienMedium", color = "FF00FFFF", align = "Left" },
  { tag = "name", font = "CRB_Interface12_BO", color = "FF00FF7F", align = "Center" },
  { tag = "title", font = "CRB_Interface10", color = "FF00FFFF", align = "Center" },
  { tag = "csentry", font = "CRB_Header13_O", color = "FF00FFFF", align = "Left" },
  { tag = "cscontents", font = "CRB_Interface12_BO", color = "FF00FF7F", align = "Left" },
}

local karRaceToString = {
  [GameLib.CodeEnumRace.Human] = Apollo.GetString("RaceHuman"),
  [GameLib.CodeEnumRace.Granok] = Apollo.GetString("RaceGranok"),
  [GameLib.CodeEnumRace.Aurin] = Apollo.GetString("RaceAurin"),
  [GameLib.CodeEnumRace.Draken] = Apollo.GetString("RaceDraken"),
  [GameLib.CodeEnumRace.Mechari] = Apollo.GetString("RaceMechari"),
  [GameLib.CodeEnumRace.Chua] = Apollo.GetString("RaceChua"),
  [GameLib.CodeEnumRace.Mordesh] = Apollo.GetString("CRB_Mordesh"),
}
-----------------------------------------------------------------------------------------------
-- Local Functions
-----------------------------------------------------------------------------------------------
local function DistanceToUnit(unitTarget)
  local unitPlayer = GameLib:GetPlayerUnit()
  
  if type(unitTarget) == "string" then
    unitTarget = GameLib.GetPlayerUnitByName(tostring(unitTarget))
  end
  
  if not unitTarget or not unitPlayer then
    return 0
  end
  
  local tPosTarget = unitTarget:GetPosition()
  local tPosPlayer = unitPlayer:GetPosition()
  
  if tPosTarget == nil or tPosPlayer == nil then
    return 0
  end
  
  local nDeltaX = tPosTarget.x - tPosPlayer.x
  local nDeltaY = tPosTarget.y - tPosPlayer.y
  local nDeltaZ = tPosTarget.z - tPosPlayer.z
  local nDistance = math.floor(math.sqrt((nDeltaX ^ 2) + (nDeltaY ^ 2) + (nDeltaZ ^ 2)))
  
  return nDistance
end

local Cozmotronic = {}
local Communicator = {}
local GeminiColor = {}
local GeminiRichText = {}

-- The constructor of our Addon.
-- We use this to create a new instance of the Addon and configure 
-- the initial settings.
function Cozmotronic:new(o)
  o = o or {}
  
  setmetatable(o, self)
  
  self.__index = self
  
  -- Configure the initial state of the Addon
  o.bInCharacter = true
  o.bHideAllNameplates = false
  o.tNameplateOptions = {}
  o.tStyles = {}
  o.tStateColors = {}
  o.arUnit2Nameplate = {}
  o.arWnd2Nameplate = {}
  
  -- Copy over the data from the constants
  for i,v in pairs(ktStyles) do
    o.tStyles[i] = v
  end
  
  for i,v in pairs(ktStateColors) do
    o.tStateColors[i] = v
  end
  
  for i,v in pairs(ktNameplateOptions) do
    o.tNameplateOptions[i] = v
  end
  
  self.unitPlayer = GameLib.GetPlayerUnit()
  
  return o
end

-- The initializer of our Addon.
-- We use this to inform the client that we have a new Addon and want to register it
-- for usage.
function Cozmotronic:Init()
  local bHasConfigureFunction = true
  local strConfigureButtonText = "Cozmotronic"
  local tDependencies = { }
  
  Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end

-- This function is called by the Client when the Addon has been registered and is ready
-- to be loaded. We will use this to trigger the XML Load and build up the forms.
function Cozmotronic:OnLoad()
  Apollo.LoadSprites("Cozmotronic_Sprites.xml", "Cozmotronic_Sprites")
  self.xmlDoc = XmlDoc.CreateFromFile("Cozmotronic.xml")
  self.xmlDoc:RegisterCallback("OnDocumentLoaded", self)
  self.strVersion = XmlDoc.CreateFromFile("toc.xml"):ToTable().Version
end

-- This function is called whenever the Addon has finished loading it's XML document.
-- When this has completed, we will attempt to load the forms and register the required
-- callbacks to make the Addon functional.
function Cozmotronic:OnDocumentLoaded()
  GeminiColor = Apollo.GetPackage("GeminiColor").tPackage
  GeminiRichText = Apollo.GetPackage("GeminiRichText").tPackage
  Communicator = Apollo.GetPackage("Communicator").tPackage
  
  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
    -- Set up the main window of our Addon.
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "MainForm", nil, self)
    
    if self.wndMain == nil then
      Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
      return
    end
    
    self.wndMain:Show(false, true)
    
    -- Set up our event handlers
    Apollo.RegisterSlashCommand("cozmo", "OnSlashCommand", self)
    Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
    Apollo.RegisterEventHandler("ToggleCozmotronic", "OnToggleCozmotronic", self)
    Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
    Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)
    Apollo.RegisterEventHandler("ChangeWorld", "OnWorldChange", self)
    Apollo.RegisterEventHandler("Communicator_VersionUpdated", "OnCommunicatorCallback", self)
    
    -- Set up our timers
    self.tmrNameplateRefresh = ApolloTimer.Create(1, true, "OnTimerRefreshNameplates", self)
    self.tmrUpdateMyNameplate = ApolloTimer.Create(5, false, "OnTimerUpdateMyNameplate", self)
    
    -- Setup Communicator
    self.Communicator = Communicator:new()
    self.Communicator:Setup("Cozmotronic")
  else
    error("Failed to load XML")    
  end
end

-- This function is called whenever the user types /cozmo.
-- We will use this to properly display the main window.
function Cozmotronic:OnSlashCommand(strCommand, strArgs)
  self.unitSelected = GameLib.GetPlayerUnit()
  self:LoadMainWindow()
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
  self.bInCharacter = not self.bInCharacter
  self:UpdateInterfaceMenuAlerts()
end

-- This function will toggle the state of the button in the InterfaceMenuList.
-- The button will  be glowing when the Addon is enabled, and dark when the
-- Addon is disabled.
function Cozmotronic:UpdateInterfaceMenuAlerts()
  local strEvent = "InterfaceMenuList_AlertAddOn"
  local strAddon = "Cozmotronic"
  local strCredits = "by Olivar Nax@Jabbit\n"
  local strStatus = self.bInCharacter and "In Character" or "Out of Character"
  local tParams = { self.bInCharacter, strCredits..strStatus, 0 }
  
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
      bEnabled = self.bEnabled,
      tNameplateOptions = self.tNameplateOptions
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
function Cozmotronic:OnRestore(eLevel, tData)
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
    self.tNameplateOptions = tData.tNameplateOptions or ktNameplateOptions
  end
  
  -- General data
  if eLevel == GameLib.CodeEnumAddonSaveLevel.General then
    return
  end
end

-- This function get's called by the Client when the play clicks on the big Configure button
-- in the main menu. Here we will show our configure window and allow the user to manipulate
-- some of the core settings for Cozmotronic.
function Cozmotronic:OnConfigure()
  self.wndOptions = Apollo.LoadForm(self.xmlDoc, "OptionsForm", nil, self)
  
  if self.wndOptions == nil then
    Apollo.AddAddonErrorText(self, "Could not load the Options Window for some reason.")
    return
  end
  
  -- Load the Settings of the Window and set the correct values to all inputs.
  local wndNameplateOptions = self.wndOptions:FindChild("wndNameplateOptions")
  
  wndNameplateOptions:FindChild("chkShowOwnNameplate"):SetCheck(self.tNameplateOptions.bShowMyNameplate)
  wndNameplateOptions:FindChild("chkShowNames"):SetCheck(self.tNameplateOptions.bShowNames)
  wndNameplateOptions:FindChild("chkShowTitles"):SetCheck(self.tNameplateOptions.bShowTitles)
  wndNameplateOptions:FindChild("chkScaleNameplates"):SetCheck(self.tNameplateOptions.bScaleNameplates)
  wndNameplateOptions:FindChild("chkShowTargetNameplate"):SetCheck(self.tNameplateOptions.bShowTargetNameplate)
  wndNameplateOptions:FindChild("input_Xoffset"):SetText(self.tNameplateOptions.nXoffset)
  wndNameplateOptions:FindChild("input_Yoffset"):SetText(self.tNameplateOptions.nYoffset)
  wndNameplateOptions:FindChild("input_NameplateDistance"):SetText(self.tNameplateOptions.nNameplateDistance)
  wndNameplateOptions:FindChild("input_Anchor"):SetText(self.tNameplateOptions.nAnchor)
  
  self.wndOptions:Show(true, false)
end

-- This function will be called every time the timer tmrUpdateMyNameplate finished it's count.
-- This function will check whether we actually need to update our own Nameplate with new
-- settings or not.
function Cozmotronic:OnTimerUpdateMyNameplate()
  self.unitPlayer = GameLib.GetPlayerUnit()
  
  if self.tNameplateOptions.bShowMyNameplate then
    self:OnCommunicatorCallback({ player = self.unitPlayer:GetName() })
  end
end

-- This function is called every time the timer tmrRefreshNameplates finished it's count.
-- This function will check whether any Nameplates need to be dereferenced or redrawn.
function Cozmotronic:OnTimerRefreshNameplates()
  for nIndex, tNameplate in pairs(self.arUnit2Nameplate) do
    if self.bHideAllNameplates == true then
      tNameplate.wndNameplate:Show(false, false)
      tNameplate.bShow = false
    else
      local bNewShow = self:VerifyVisibilityOptions(tNameplate) and (DistanceToUnit(tNameplate.unitOwner) <= self.tNameplateOptions.nNameplateDistance)
      
      if bNewShow ~= tNameplate.bShow then
        tNameplate.wndNameplate:Show(bNewShow, false)
        tNameplate.bShow = bNewShow
      end
      
      self:DrawNameplate(tNameplate)
    end
  end
end

-- This function is the callback for the UnitCreated event of the game.
-- Every time a unit is created in the game world, this function is triggered.
-- If the created unit is a Player, we will attempt to obtain his information using
-- the Communicator library.
function Cozmotronic:OnUnitCreated(unitCreated)
  if not self.unitPlayer then
    self.unitPlayer = GameLib.GetPlayerUnit()
  end
  
  if unitCreated:IsThePlayer() then
    self:OnCommunicatorCallback({ player = unitCreated:GetName() })
  end
  
  if unitCreated:IsACharacter() then
    for i, strPlayerName in pairs(self.Communicator:GetCachedPlayerList()) do
      if unitCreated:GetName() == strPlayerName then
        self:OnCommunicatorCallback({ player = unitCreated:GetName() })
      end
    end
    
    local rpVersion, rpAddons = self.Communicator:QueryVersion(unitCreated:GetName())
  end
end

-- This function is the callback for the "ChangeWorld" Event of the Game.
-- Every time we change worlds/maps, this function will be called.
-- When this happens, we destroy all references we have to the Nameplate entries
-- for the players we have tracked.
function Cozmotronic:OnWorldChange()
  for nIndex, _ in pairs(self.arUnit2Nameplate) do
    local wndNameplate = self.arUnit2Nameplate[nIndex].wndNameplate
    
    wndNameplate:Destroy()
    
    self.arWnd2Nameplate[nIndex] = nil
    self.arUnit2Nameplate[nIndex] = nil
  end
  
  self.tmrUpdateMyNameplate:Start()
end

-- This function is the callback for Communicator.
-- Every time Communicator updates information, the Event "Communicator_VersionUpdated" is raised.
-- When listening to that event, this function is called, and allows us to process the new data
-- that has been received.
function Cozmotronic:OnCommunicatorCallback(tArgs)
  local strUnitName = tArgs.player  
  local unit = GameLib.GetPlayerUnitByName(strUnitName)
  
  if unit == nil then
    return
  end
  
  local idUnit = unit:GetId()
  
  if self.arUnit2Nameplate[unit] ~= nil and self.arUnit2Nameplate[idUnit].wndNameplate:IsValid() then
    return
  end
  
  local wnd = Apollo.LoadForm(self.xmlDoc, "OverheadForm", "InWorldHudStratum", self)
  
  wnd:Show(false, true)
  wnd:SetUnit(unit, self.tNameplateOptions.nAnchor)
  wnd:SetName("wnd_"..strUnitName)
  
  local tNameplate = {
    unitOwner = unit,
    idUnit = unit:GetId(),
    unitName = strUnitName,
    wndNameplate = wnd,
    bOnScreen = wnd:IsOnScreen(),
    bOccluded = wnd:IsOccluded(),
    eDisposition = unit:GetDispositionTo(self.unitPlayer),
    bShow = false
  }
  
  wnd:SetData({ unitName = strUnitName, unitOwner = unit })
  
  self.arUnit2Nameplate[idUnit] = tNameplate
  self.arWnd2Nameplate[wnd:GetId()] = tNameplate
  
  self:DrawNameplate(tNameplate)
end

-- This function is the callback for the UnitDestroyed event.
-- This event is raised every time a unit in the game world is destroyed.
-- We use this callback to clean up the internal data when the destroyed unit is a player
-- we are tracking.
function Cozmotronic:OnUnitDestroyed(unitDestroyed)
  if unitDestroyed:IsACharacter() then
    local idUnit = unitDestroyed:GetId()
    
    if self.arUnit2Nameplate[idUnit] == nil then
      return
    end
    
    local wndNameplate = self.arUnit2Nameplate[idUnit].wndNameplate
    
    self.arWnd2Nameplate[wndNameplate:GetId()] = nil
    
    wndNameplate:Destroy()
    
    self.arUnit2Nameplate[idUnit] = nil
  end
end

-- This function is a helper function to determine the visibility options of the given nameplate.
-- The function will return true if the provided nameplate is visible; otherwise false.
function Cozmotronic:VerifyVisibilityOptions(tNameplate)
  local unitOwner = tNameplate.unitOwner
  local bHiddenUnit = not unitOwner:ShouldShowNamePlate()
  
  if bHiddenUnit then
    return false
  end
  
  if tNameplate.bOccluded or not tNameplate.bOnScreen then
    return false
  end
  
  if unitOwner:IsThePlayer() then
    return self.tNameplateOptions.bShowMyNameplate
  end
  
  if self.tNameplateOptions.bShowTargetNameplate == true then
    return GameLib.GetTargetUnit() == unitOwner
  end
  
  return true
end

-- This function is triggered every time the occlusion changes of a unit.
-- This event is registered for the overhead RP display, and we use this to
-- update the occlusion settings of our Nameplates.
function Cozmotronic:OnUnitOcclusionChanged(wndHandler, wndControl, bOccluded)
  local idUnit = wndHandler:GetId()
  
  if self.arWnd2Nameplate[idUnit] ~= nil then
    self.arWnd2Nameplate[idUnit].bOccluded = bOccluded
    
    self:UpdateNameplateVisibility(self.arWnd2Nameplate[idUnit])
  end
end

-- This function updates the visibility of the nameplate, keeping the distance and
-- occlusion in mind.
function Cozmotronic:UpdateNameplateVisibility(tNameplate)
  local bNewShow = self:VerifyVisibilityOptions(tNameplate) and (DistanceToUnit(tNameplate.unitOwner) <= self.tNameplateOptions.nNameplateDistance)
  
  if bNewShow ~= tNameplate.bShow then
    tNameplate.wndNameplate:Show(bNewShow, false)
    tNameplate.bShow = bNewShow
  end
end

-- This function is a callback for the onWorld Screen-location being changed.
-- This is triggered by our RP button, and used to determine whether the new
-- location is still onScreen or not.
function Cozmotronic:OnWorldLocationOnScreen(wndHandler, wndControl, bOnScreen)
  local idUnit = wndHandler:GetId()
  
  if self.arWnd2Nameplate[idUnit] ~= nil then
    self.arWnd2Nameplate[idUnit].bOnScreen = bOnScreen
  end
end

-- Draws the provided Nameplate on screen when all conditions are met.
function Cozmotronic:DrawNameplate(tNameplate)
  if not tNameplate.bShow then
    return
  end
  
  local unitPlayer = self.unitPlayer
  local unitOwner = tNameplate.unitOwner
  local wndNameplate = tNameplate.wndNameplate
  
  tNameplate.eDisposition = unitOwner:GetDispositionTo(unitPlayer)
  
  if unitOwner:IsMounted() and wndNameplate:GetUnit() == unitOwner then
    wndNameplate:SetUnit(unitOwner:GetUnitMount(), 1)
  elseif not unitOwner:IsMounted()and wndNameplate:GetUnit() ~= unitOwner then
    wndNameplate:SetUnit(unitOwner, self.tNameplateOptions.Anchor)
  end
  
  local bShowNameplate = (DistanceToUnit(tNameplate.unitOwner) <= self.tNameplateOptions.nNameplateDistance) and  self:VerifyVisibilityOptions(tNameplate)
  
  wndNameplate:Show(bShowNameplate, false)
  
  if not bShowNameplate then
    return
  end
  
  if self.tNameplateOptions.nXoffset or self.tNameplateOptions.nYoffset then
    wndNameplate:SetAnchorOffsets(
      -15 + (self.tNameplateOptions.nXoffset or 0),
      -15 + (self.tNameplateOptions.nYoffset or 0),
      15 + (self.tNameplateOptions.nXoffset or 0),
      15 + (self.tNameplateOptions.nYoffset or 0)
    )
  end
  
  if self.tNameplateOptions.bScaleNameplates == true then
    self:ScaleNameplate(tNameplate)
  end
  
  self:DrawRPNameplate(tNameplate)
end

-- This function draws the RP nameplate on the screen for those who are actually running
-- the Addon.
function Cozmotronic:DrawRPNameplate(tNameplate)
  local tRPColors, tCSColors
  local rpFullname, rpTitle, rpStatus
  local unitName = tNameplate.unitName
  local xmlNamePlate = XmlDoc:new()
  local wndNameplate = tNameplate.wndNameplate
  local wndData = wndNameplate:FindChild("wnd_Data")
  local btnRP = wndNameplate:FindChild("btn_RP")
  
  rpFullname = self.Communicator:GetTrait(unitName,self.Communicator.CodeEnumTrait.Name) or unitName
  rpTitle = self.Communicator:FetchTrait(unitName, self.Communicator.CodeEnumTrait.NameAndTitle)
  rpStatus = self.Communicator:GetTrait(unitName, self.Communicator.CodeEnumTrait.RPFlag)
  
  local strNameString = ""
  
  if self.tNameplateOptions.bShowNames == true then
    strNameString = strNameString .. string.format("{name}%s{/name}\n", rpFullname)
    
    if self.tNameplateOptions.bShowTitles == true and rpTitle ~= nil then
      strNameString = strNameString .. string.format("{title}%s{/title}", rpTitle)
    end
  end
  
  local strNamePlate = GeminiRichText:ParseMarkup(strNameString, self.tStyles)

  wndData:SetAML(strNamePlate)
  wndData:SetHeightToContentHeight()
  
  if rpStatus == nil then
    rpStatus = 0 
  end
  
  local strState = self.Communicator:FlagsToString(rpStatus)
  local xmlTooltip = XmlDoc.new()
  
  xmlTooltip:StartTooltip(Tooltip.TooltipWidth)
  
  if self.tNameplateOptions.bShowNames == false then
    xmlTooltip:AddLine(rpFullname, "FF009999", "CRB_InterfaceMedium_BO")
    
    if self.tNameplateOptions.bShowTitles == true and rpTitle ~= nil then
      xmlTooltip:AddLine(rpTitle, "FF99FFFF", "CRB_InterfaceMedium_BO")
    end
    
    xmlTooltip:AddLine("――――――――――――――――――――", "FF99FFFF", "CRB_InterfaceMedium_BO")
  end
  
  xmlTooltip:AddLine(strState, self.tStateColors[rpStatus], "CRB_InterfaceMedium_BO")
  btnRP:SetTooltipDoc(xmlTooltip)
  btnRP:SetBGColor(self.tStateColors[rpStatus] or "FFFFFFFF")
end

-- Scales the Nameplate based on the distance and location of nameplate.
function Cozmotronic:ScaleNameplate(tNameplate)
  if tNameplate.unitOwner:IsThePlayer() then
    return
  end
  
  local wndNameplate = tNameplate.wndNameplate
  local nDistance = DistanceToUnit(tNameplate.unitOwner)
  local fDistancePercentage = ((self.tNameplateOptions.nNameplateDistance / nDistance) - 0.5)
  
  if fDistancePercentage > 1 then
    fDistancePercentage = 1
  end
  
  wndNameplate:SetScale(fDistancePercentage)
end

function Cozmotronic:ClearCache()
  self.Communicator:ClearCachedPlayerList()
end

-- Loads the main window to be displayed for the specified target.
-- If the specified target cannot be found, then we will assume we're displaying
-- our own information.
function Cozmotronic:LoadMainWindow(strTarget)
  local wndProfile = self.wndMain:FindChild("wndProfile")
  local wndBiography = self.wndMain:FindChild("wndBiography")
  local strFirstName, strLastName, strTitle, strOccupation, strGender, strRace, strAge, strHeight, strWidth, strWeight, strBuild, strDescription, strBiography
  
  if strTarget == nil or strTarget == GameLib:GetPlayerUnit():GetName() then
    strFirstName = self.Communicator:GetLocalTrait("first_name") or ""
    strLastName = self.Communicator:GetLocalTrait("last_name") or ""
    strTitle = self.Communicator:GetLocalTrait("title") or ""
    strOccupation = self.Communicator:GetLocalTrait("occupation") or ""
    strGender = self.Communicator:GetLocalTrait("gender") or ""
    strRace = karRaceToString[self.unitPlayer:GetRaceId()]
    strAge = self.Communicator:GetLocalTrait("age") or ""
    strHeight = self.Communicator:GetLocalTrait("height") or ""
    strWidth = self.Communicator:GetLocalTrait("width") or ""
    strWeight = self.Communicator:GetLocalTrait("weight") or ""
    strBuild = self.Communicator:GetLocalTrait("build") or ""
    strDescription = self.Communicator:GetLocalTrait("description") or ""
    strBiography = self.Communicator:GetLocalTrait("biography") or ""
  else
    strFirstName = self.Communicator:GetTrait("first_name", strTarget) or ""
    strLastName = self.Communicator:GetTrait("last_name", strTarget) or ""
    strTitle = self.Communicator:GetTrait("title", strTarget) or ""
    strOccupation = self.Communicator:GetTrait("occupation", strTarget) or ""
    strGender = self.Communicator:GetTrait("gender", strTarget) or ""
    strRace = self.Communicator:GetTrait("race", strTarget) or ""
    strAge = self.Communicator:GetTrait("age", strTarget) or ""
    strHeight = self.Communicator:GetTrait("height", strTarget) or ""
    strWidth = self.Communicator:GetTrait("width", strTarget) or ""
    strWeight = self.Communicator:GetTrait("weight", strTarget) or ""
    strBuild = self.Communicator:GetTrait("build", strTarget) or ""
    strDescription = self.Communicator:GetTrait("description", strTarget) or ""
    strBiography = self.Communicator:GetTrait("biography", strTarget) or ""
    
    wndProfile:FindChild("btnSave"):Show(false, false)
  end
  
  -- Set all data on the form.  
  wndProfile:FindChild("input_FirstName"):SetText(strFirstName)
  wndProfile:FindChild("input_LastName"):SetText(strLastName)
  wndProfile:FindChild("input_Title"):SetText(strTitle)
  wndProfile:FindChild("input_Occupation"):SetText(strOccupation)
  wndProfile:FindChild("input_Gender"):SetText(strGender)
  wndProfile:FindChild("input_Race"):SetText(strRace)
  wndProfile:FindChild("input_Age"):SetText(strAge)
  wndProfile:FindChild("input_Height"):SetText(strHeight)
  wndProfile:FindChild("input_Width"):SetText(strWidth)
  wndProfile:FindChild("input_Weight"):SetText(strWeight)
  wndProfile:FindChild("input_Build"):SetText(strBuild)
  wndBiography:FindChild("input_Description"):SetText(strDescription)
  wndBiography:FindChild("input_Biography"):SetText(strBiography)
  
  self.wndMain:Show(true, false)
end
-----------------------------------------------------------------------------------------------
-- Form and Button Functions
-----------------------------------------------------------------------------------------------
function Cozmotronic:OnRPButtonClick(wndHandler, wndControl, eMouseButton)
  local tUnit = wndControl:GetParent():GetData()
  
  self:LoadMainWindow(tUnit.unitName)
end

function Cozmotronic:OnBtnClearCacheOptionsForm(wndHandler, wndControl, eMouseButton)
  self:ClearCache()
end

function Cozmotronic:OnBtnSaveOptionsForm(wndHandler, wndControl, eMouseButton)
  local wndNameplateOptions = self.wndOptions:FindChild("wndNameplateOptions")
  
  self.tNameplateOptions = {
    bShowMyNameplate = wndNameplateOptions:FindChild("chkShowOwnNameplate"):IsChecked(),
    bShowNames = wndNameplateOptions:FindChild("chkShowNames"):IsChecked(),
    bShowTitles = wndNameplateOptions:FindChild("chkShowTitles"):IsChecked(),
    bScaleNameplates = wndNameplateOptions:FindChild("chkScaleNameplates"):IsChecked(),
    bShowTargetNameplate = wndNameplateOptions:FindChild("chkShowTargetNameplate"):IsChecked(),
    nXoffset = tonumber(wndNameplateOptions:FindChild("input_Xoffset"):GetText())  or ktNameplateOptions.nXoffset,
    nYoffset = tonumber(wndNameplateOptions:FindChild("input_Yoffset"):GetText()) or ktNameplateOptions.nYoffset,
    nNameplateDistance = tonumber(wndNameplateOptions:FindChild("input_NameplateDistance"):GetText()) or ktNameplateOptions.nNameplateDistance,
    nAnchor = tonumber(wndNameplateOptions:FindChild("input_Anchor"):GetText()) or ktNameplateOptions.nAnchor
  }
  
  self.wndOptions:Show(false, false)
end

-- This function is called whenever the user clicks on the green save button of the Mainform.
-- When this happens, we will save ALL data that has been entered for the current player.
function Cozmotronic:OnBtnSaveMainForm(wndHanlder, wndControl, eMouseButton)
  if self.unitSelected == nil or self.unitSelected == self.unitPlayer then
    local wndProfile = self.wndMain:FindChild("wndProfile")
    local wndBiography = self.wndMain:FindChild("wndBiography")
    local strFirstName = wndProfile:FindChild("input_FirstName"):GetText()
    local strLastName = wndProfile:FindChild("input_LastName"):GetText()
    local strTitle = wndProfile:FindChild("input_Title"):GetText()
    local strOccupation = wndProfile:FindChild("input_Occupation"):GetText()
    local strGender = wndProfile:FindChild("input_Gender"):GetText()
    local strRace = wndProfile:FindChild("input_Race"):GetText()
    local strAge = wndProfile:FindChild("input_Age"):GetText()
    local strHeight = wndProfile:FindChild("input_Height"):GetText()
    local strWidth = wndProfile:FindChild("input_Width"):GetText()
    local strWeight = wndProfile:FindChild("input_Weight"):GetText()
    local strBuild = wndProfile:FindChild("input_Build"):GetText()
    local strDescription = wndBiography:FindChild("input_Description"):GetText()
    local strBiography = wndBiography:FindChild("input_Biography"):GetText()
    
    self.Communicator:SetLocalTrait("first_name", strFirstName)
    self.Communicator:SetLocalTrait("last_name", strLastName)
    self.Communicator:SetLocalTrait("title", strTitle)
    self.Communicator:SetLocalTrait("occupation", strOccupation)
    self.Communicator:SetLocalTrait("gender", strGender)
    self.Communicator:SetLocalTrait("race", strRace)
    self.Communicator:SetLocalTrait("age", strAge)
    self.Communicator:SetLocalTrait("height", strHeight)
    self.Communicator:SetLocalTrait("width", strWidth)
    self.Communicator:SetLocalTrait("weight", strWeight)
    self.Communicator:SetLocalTrait("build", strBuild)
    self.Communicator:SetLocalTrait("description", strDescription)
    self.Communicator:SetLocalTrait("biography", strBiography)
    
    self.wndMain:Show(false, false)
  end
end
-----------------------------------------------------------------------------------------------
-- Cozmotronic Instance
-----------------------------------------------------------------------------------------------
local CozmotronicInst = Cozmotronic:new()
CozmotronicInst:Init()