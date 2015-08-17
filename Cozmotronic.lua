-----------------------------------------------------------------------------------------------
-- Client Lua Script for Cozmotronic
-- Copyright (c) NCsoft. All rights reserved
----------------------------------------------------------------------------------------------- 
require "Window"

-----------------------------------------------------------------------------------------------
-- Cozmotronic Module Definition
-----------------------------------------------------------------------------------------------
local Cozmotronic = {} 
local Communicator = nil
local GeminiColor
local GeminiRichText
local PerspectivePlates
local ksVersion

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local ktLocalizationStrings = {
  enUS = {
    _name = "Name",
    _title = "Title",
    _species = "Species",
    _gender = "Gender",
    _age = "Age",
    _height = "Height",
    _build = "Build",
    _occupation = "Occupation",
    _description = "Description",
    _slashHelp = " \nPDA Help:\n----------------------------\nType /cozmo off to hide all nameplates.\nType /cozmo on to show nameplates.\nType /cozmo status [0-7] to change your RP Flag status.\nType /cozmo to show the main UI.",
  },
  frFR= {
    _name = "Nom",
    _title = "Titre",
    _species = "Race",
    _gender = "Sexe",
    _age = "Age",
    _height = "Taille",
    _build = "Carrure",
    _occupation = "Profession",
    _description = "Description",
    _slashHelp = " \nPDA Aide:\n----------------------------\nEntrez /cozmo off pour cacher toutes les Plaques d’Identification.\nEntrez /cozmo on pour révéler les Plaques d’Identification.\nEntrez /cozmo status [0-7] Pour changer votre status RP Flag.\nEntrez /cozmo pour révéler l’interface principale.",
  },
  deDE= {
    _name = "Name",
    _title = "Titel",
    _species = "Spezies",
    _gender = "Geschlecht",
    _age = "Lebensdauer",
    _height = "Höhe",
    _build = "Körperbau",
    _occupation = "Beruf",
    _description = "Darstellung",
    _slashHelp = " \nPDA Hilfe:\n----------------------------\nTyp /cozmo aus, um alle Namensschilder verstecken.\nTyp /cozmo auf Namensschilder zeigen.\nTyp /cozmo status [0-7], um die RP Flag Status zu ändern.\nTyp /cozmo, um die Haupt-UI zeigen.",
  },
}

local karRaceToString = {
	[GameLib.CodeEnumRace.Human] = Apollo.GetString("RaceHuman"),
	[GameLib.CodeEnumRace.Granok] = Apollo.GetString("RaceGranok"),
	[GameLib.CodeEnumRace.Aurin] = Apollo.GetString("RaceAurin"),
	[GameLib.CodeEnumRace.Draken] = Apollo.GetString("RaceDraken"),
	[GameLib.CodeEnumRace.Mechari] = Apollo.GetString("RaceMechari"),
	[GameLib.CodeEnumRace.Chua] = Apollo.GetString("RaceChua"),
	[GameLib.CodeEnumRace.Mordesh] = Apollo.GetString("CRB_Mordesh")
}

local karGenderToString = {
	[Unit.CodeEnumGender.Male] = Apollo.GetString("CRB_Male"),
	[Unit.CodeEnumGender.Female] = Apollo.GetString("CRB_Female"),
	[Unit.CodeEnumGender.Uni] = Apollo.GetString("CRN_UnknownType")
}
 
local ktNameplateOptions = {
	nXoffset = 0,
	nYoffset = -50,
	bShowMyNameplate = true,
	bShowNames = true,
	bShowTitles = true,
	bScaleNameplates = false,
	bnNameplateDistance = 50,
	nAcnhor = 1,
	bShowTargetNameplate = false
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
	{tag = "h1", font = "CRB_Interface14_BBO", color = "FF00FA9A", align = "Center"},
	{tag = "h2", font = "CRB_Interface12_BO", color = "FF00FFFF", align = "Left"},
	{tag = "h3", font = "CRB_Interface12_I", color = "FF00FFFF", align = "Left"},
	{tag = "p", font = "CRB_Interface12", color = "FF00FFFF", align = "Left"},
	{tag = "li", font = "CRB_Interface12", color = "FF00FFFF", align = "Left", bullet = "?", indent = "  "},
	{tag = "alien", font = "CRB_AlienMedium", color = "FF00FFFF", align = "Left"},
	{tag = "name", font = "CRB_Interface12_BO", color = "FF00FF7F", align = "Center"},
	{tag = "title", font = "CRB_Interface10", color = "FF00FFFF", align = "Center"},
	{tag = "csentry", font = "CRB_Header13_O", color = "FF00FFFF", align = "Left"},
	{tag = "cscontents", font = "CRB_Interface12_BO", color = "FF00FF7F", align = "Left"},
}

local ktRaceSprites = {
	[GameLib.CodeEnumRace.Human] = {
		[0] = "CRB_CharacterCreateSprites:btnCharC_RG_HuM_ExFlyby",
		[1] = "CRB_CharacterCreateSprites:btnCharC_RG_HuF_ExFlyby", 
		[2] = "CRB_CharacterCreateSprites:btnCharC_RG_HuM_DomFlyby", 
		[3] = "CRB_CharacterCreateSprites:btnCharC_RG_HuF_DomFlyby" },
	[GameLib.CodeEnumRace.Granok] = {
		[0] = "CRB_CharacterCreateSprites:btnCharC_RG_GrMFlyby", 
		[1] = "CRB_CharacterCreateSprites:btnCharC_RG_GrFFlyby" },
	[GameLib.CodeEnumRace.Aurin] = {
		[0] = "CRB_CharacterCreateSprites:btnCharC_RG_AuMFlyby", 
		[1] = "CRB_CharacterCreateSprites:btnCharC_RG_AuFFlyby" },
	[GameLib.CodeEnumRace.Draken] = {
		[0] = "CRB_CharacterCreateSprites:btnCharC_RG_DrMFlyby", 
		[1] = "CRB_CharacterCreateSprites:btnCharC_RG_DrFFlyby" },
	[GameLib.CodeEnumRace.Mechari] = {
		[0] = "CRB_CharacterCreateSprites:btnCharC_RG_MeMFlyby",
		[1] = "CRB_CharacterCreateSprites:btnCharC_RG_MeFFlyby" },
	[GameLib.CodeEnumRace.Chua] = {
		[0] = "CRB_CharacterCreateSprites:btnCharC_RG_ChuFlyby",
		[1] = "CRB_CharacterCreateSprites:btnCharC_RG_ChuFlyby" },
	[GameLib.CodeEnumRace.Mordesh] = {
		[0] = "CRB_CharacterCreateSprites:btnCharC_RG_MoMFlyby",
		[1] = "CRB_CharacterCreateSprites:btnCharC_RG_MoMFlyby"},
}

-----------------------------------------------------------------------------------------------
-- Local Functions
-----------------------------------------------------------------------------------------------
-- Compares the versions of the Addon.
local function CompareVersions(strVersionChecking)  
  local strVersionCurrent = ksVersion
  
  if not (type(strVersionCurrent) == "string" or type(strVersionCurrent) == "number") then return false end
  if not (type(strVersionChecking) == "string" or type(strVersionChecking) == "number") then return false end
  
  local tVersionCurrent = strsplit(".", strVersionCurrent);
  local tVersionChecking = strsplit(".", strVersionChecking);
  
  return CompareVersionNumberTable(tVersionCurrent, tVersionChecking);
end

-- Calculates the distance to the given unit.
local function DistanceToUnit(unitTarget)	
	local unitPlayer = GameLib.GetPlayerUnit()
	
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

-- Gets the Locale in which the client is currently running.
local function GetLocale()
	local strCancel = Apollo.GetString("CRB_Cancel")

	if strCancel == "Annuler" and ktLocalizationStrings["frFR"] then
		return "frFR"
	elseif strCancel == "Abbrechen" and ktLocalizationStrings["deDE"] then
		return "deDE"
	else
		return "enUS"
	end
end

-- Splits a given string on the given separator, returning all the fields
-- as an array of strings.
local function strsplit(sep, str)
		local sep, fields = sep or ":", {}
		local pattern = string.format("([^%s]+)", sep)
		string.gsub(str ,pattern, function(c) fields[#fields+1] = c end)
		return fields
end

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Cozmotronic:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self 
  
  -- initialize variables here
  self.tPlayers = {}                          -- Used for tracking all players in the channel.
  self.tOptions = {}                          -- Used for tracking all our RP options.
  self.tDisplayOptions = {}                   -- Used for temporarely storing the RP options of another player.
  self.tSettings = {}                         -- Used for storing the Cozmotronic Configuration.
  self.tNameplateOptions = {}                 -- Used for storing the nameplate configuration.
  self.arUnit2Nameplate = {}                  -- Tracking all UnitIds for the nameplates
  self.arWnd2Nameplate = {}                   -- Tracking all WindowIds for the nameplates
  self.bHideAllNameplates = false             -- By default we do not hide nameplates.
  self.unitPlayer = GameLib.GetPlayerUnit()   -- Track ourselves.

  -- Configure the styles, colours and other required settings.
  for i,v in pairs(ktStyles) do
    o.tStyles[i] = v
  end
  
  for i,v in pairs(ktStateColors) do
    o.tStateColors[i] = v
  end
  
  for i,v in pairs(ktNamePlateOptions) do
    o.tNamePlateOptions[i] = v
  end
  
  return o
end

function Cozmotronic:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
    "GeminiColor",
    "GeminiRichText",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- Cozmotronic OnLoad
-----------------------------------------------------------------------------------------------
function Cozmotronic:OnLoad()
  Apollo.LoadSprites("PDA_Sprites.xml", "PDA_Sprites")
  self.xmlDoc = XmlDoc.CreateFromFile("Cozmotronic.xml")
  self.xmlDoc:RegisterCallback("OnDocLoaded", self)
  ksVersion = XmlDoc.CreateFromFile("toc.xml"):ToTable().Version
end

-----------------------------------------------------------------------------------------------
-- Cozmotronic OnDocLoaded
-----------------------------------------------------------------------------------------------
function Cozmotronic:OnDocLoaded()
  if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
    self.wndMain = Apollo.LoadForm(self.xmlDoc, "wndMain", nil, self)
    self.wndError = Apollo.LoadForm(self.xmlDoc, "wndError", nil, self)
  
    if self.wndMain == nil then
      Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
      return
    end
  
    if self.wndError == nil then
      Apollo.AddAddonErrorText(self, "Could not load the error window for some reason.")
      return
    end
  
    -- Don't show any of our Forms
    self.wndMain:Show(false)
    self.wndError:Show(false)
    
    -- if the xmlDoc is no longer needed, you should set it to nil
    -- self.xmlDoc = nil
  
    -- Register handlers for events, slash commands and timer, etc.
    -- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
    Apollo.RegisterSlashCommand("cozmo", "OnCozmotronicOn", self)
    Apollo.RegisterEventHandler("UnitCreated","OnUnitCreated",self) 
    Apollo.RegisterEventHandler("UnitDestroyed","OnUnitDestroyed",self)
    Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuListHasLoaded", self)
    Apollo.RegisterEventHandler("ToggleAddon_PDA", "OnPDAOn", self)
    Apollo.RegisterEventHandler("Communicator_VersionUpdated", "OnCommunicatorCallback", self)
    Apollo.RegisterEventHandler("ChangeWorld", "OnWorldChange", self)
  
    -- Create the timers for our Addon
    self.tmrNamePlateRefresh = ApolloTimer.Create(1, true, "RefreshPlates", self)
    self.tmrUpdateMyNameplate = ApolloTimer.Create(5, false, "UpdateMyNameplate", self)
    self.tmrRefreshCharacterSheet = ApolloTimer.Create(3, true, "UpdateCharacterSheet", self)
    self.tmrRefreshCharacterSheet:Stop()
    
    -- Check the Locale we're running in
    self.locale = GetLocale()
    
    -- Do additional Addon initialization here
    Communicator = Apollo.GetPackage("Communicator").tPackage
    GeminiColor = Apollo.GetPackage("GeminiColor").tPackage
    GeminiRichText = Apollo.GetPackage("GeminiRichText").tPackage
    PerspectivePlates = Apollo.GetAddon("PerspectivePlates")
    
    self.bCommunicatorLoaded = true
  
    if Communicator == nil then
      self.bCommunicatorLoaded = false
      self.wndError:Show(true)
    end
  end
end


-----------------------------------------------------------------------------------------------
-- Event Handlers
-----------------------------------------------------------------------------------------------
-- This function is called whenever the user changes worlds or zones.
-- We will use this hook to update the nameplates for our player and detect potential new
-- players.
function Cozmotronic:OnWorldChange()
  for i,v in pairs(self.arUnit2Nameplate) do
    local wndNameplate = self.arUnit2Nameplate[i].wndNameplate
    wndNameplate:Destroy()
    self.arWnd2Nameplate[i] = nil
    self.arUnit2Nameplate[i] = nil
  end
  
  self.tmrUpdateMyNameplate:Start()
end

-- This function is called whenever a unit is created in the same world as our Player.
-- We use this function to figure out if this unit is actually a player and if he is
-- running Cozmotronic.
function Cozmotronic:OnUnitCreate(unitNew)
  if not self.unitPlayer then
    self.unitPlayer = GameLib.GetPlayerUnit()
  end
  
  if unitNew:IsThePlayer() then
    self:OnCommunicatorCallback({ player = unitNew:GetName() })
  end
  
  if unitNew:IsACharacter() then
    for i, player in pairs(Communicator:GetCachedPlayerList()) do
      if unitNew:GetName() == player then
        self:OnCommunicatorCallback({ player = unitNew:GetName() })
      end
    end
    
    local rpVersion, rpAddons = Communicator:QueryVersion(unitNew:GetName())
  end
end

-- This function is used to handle callbacks from Communicator itself.
-- Often used for querying or storing information about units found in the world.
function Cozmotronic:OnCommunicatorCallback(tArgs)
  local strUnitName = tArgs.player
  local unit = GameLib.GetPlayerUnitByName(strUnitName)
  
  if unit == nil then return end
  
  local idUnit = unit:GetId()
  
  if self.arUnit2Nameplate[idUnit] ~= nil and self.arUnit2Nameplate[idUnit].wndNameplate:IsValid() then
    return
  end
  
  local wnd = Apollo.LoadForm(self.xmlDoc, "OverheadForm", "InWorldHudStratum", self)
  
  wnd:Show(false, true)
  wnd:SetUnit(unit, self.tNamePlateOptions.nAnchor)
  wnd:SetName("wnd_"..strUnitName)
  
  local tNameplate =
  {
    unitOwner     = unit,
    idUnit      = unit:GetId(),
    unitName    = strUnitName,
    wndNameplate  = wnd,
    bOnScreen     = wnd:IsOnScreen(),
    bOccluded     = wnd:IsOccluded(),
    eDisposition  = unit:GetDispositionTo(self.unitPlayer),
    bShow     = false,
  }
  
  wnd:SetData(
    {
      unitName = strUnitName,
      unitOwner = unit,
    }
  )
  
  self.arUnit2Nameplate[idUnit] = tNameplate
  self.arWnd2Nameplate[wnd:GetId()] = tNameplate  
  self:DrawNameplate(tNameplate)
end

-- This function is called whenever a unit is destroyed in the same world as the player.
-- We use this callback to cleanup our caches and ensure we don't cary around obsolete data.
function Cozmotronic:OnUnitDestroyed(unitOwner)
  if unitOwner:IsACharacter() then
    local idUnit = unitOwner:GetId()
    
    if self.arUnit2Nameplate[idUnit] == nil then
      return
    end
    
    local wndNameplate = self.arUnit2Nameplate[idUnit].wndNameplate
    
    self.arWnd2Nameplate[wndNameplate:GetId()] = nil
    wndNameplate:Destroy()
    self.arUnit2Nameplate[idUnit] = nil
  end
end

-----------------------------------------------------------------------------------------------
-- Cozmotronic Functions
-----------------------------------------------------------------------------------------------
-- This function is called whenever the user types the /cozmo command in chat.
-- When this happens, we will load the main form and display all information that he has entered
-- so far.
function Cozmotronic:OnCozmotronicOn()
  local unitPlayer = GameLib.GetPlayerUnit()
  if unitPlayer == nil then return end  -- Prevent data retrieval if the player is not loaded.
	
	-- Show the window
	if self.bCommunicatorLoaded then
    self.strSelectedPlayer = unitPlayer:GetName()
    
    self:LoadAndDisplayLocalTrait("Name")
    self:LoadAndDisplayLocalTrait("Title")
    self:LoadAndDisplayLocalTrait("Age")
    self:LoadAndDisplayLocalTrait("Gender")
    self:LoadAndDisplayLocalTrait("Height")
    self:LoadAndDisplayLocalTrait("Weight")
    self:LoadAndDisplayLocalTrait("Description")
    
    self.wndMain:Invoke()
  else
    self.wndError:Invoke()
  end	
end

-- This function is a small helper method that will load the information from the inputs
-- on the main form and store them in Communicator as local traits using the provided name.
-- The function assumes that the trait is represented on the main Window as an input with the
-- same name.
function Cozmotronic:LoadAndStoreLocalTrait(strTrait)
  local tInput = self.wndMain:FindChild("input"..strTrait)
  
  if tInput and self.bCommunicatorLoaded then
    Communicator:SetLocalTrait(strTrait, tInput:GetText())
  end
end

-- This function is a small helper method that will load the specified train from Communicator
-- and display it on the main form. The function assumes the main form to have an input field
-- with matching name as the provided trait.
function Cozmotronic:LoadAndDisplayLocalTrait(strTrait)
  local tInput = self.wndMain:FindChild("input"..strTrait)
  
  if tInput and self.bCommunicatorLoaded then
    tInput:SetText(Communicator:GetLocalTrait(strTrait))
  end
end

-- This function is called every second by our internal timer, and is used to update our
-- nameplate in order to display the big RP button on top of it.
function Cozmotronic:RefreshPlates()
  for idx, tNameplate in pairs(self.arUnit2Nameplate) do
    if self.bHideAllNameplates == true then
      tNameplate.wndNameplate:Show(false, false)
      tNameplate.bShow = false
    else
      local bNewShow = self:HelperVerifyVisibilityOptions(tNameplate) and (DistanceToUnit(tNameplate.unitOwner))
      
      if bNewShow ~= tNameplate.bShow then
        tNameplate.wndNameplate:Show(bNewShow, false)
        tNameplate.bShow = bNewShow
      end
      
      self:DrawNameplate(tNameplate)
    end
  end
end

-- This function verifies whether the supplied nameplate is actually close enough to be visible
-- for the player. When this is the case, true is returned; otherwise false.
-- Any occlusion will result in fals being returned as well.
function Cozmotronic:HelperVerifyVisibilityOptions(tNameplate)
  local unitOwner = tNameplate.unitOwner
  local bHiddenUnit = not unitOwner:ShouldShowNamePlate()
  
  if bHiddenUnit then
    return false
  end
    
  if tNameplate.bOccluded or not tNameplate.bOnScreen then
    return false
  end
    
  if unitOwner:IsThePlayer() then
    return self.tNamePlateOptions.bShowMyNameplate
  end
  
  if self.tNamePlateOptions.bShowTargetNameplate == true then
    return GameLib.GetTargetUnit() == unitOwner
  end
    
  return true
end

-- This function is called whenever the Occlusion of a unit changes.
-- When this happens, we check if we need to change anything with the nameplates for the
-- unit that is being occluded from sight.
function Cozmotronic:OnUnitOcclusionChanged(wndHandler, wndControl, bOccluded)
  local idUnit = wndHandler:GetId()
  
  if self.arWnd2Nameplate[idUnit] ~= nil then
    self.arWnd2Nameplate[idUnit].bOccluded = bOccluded
    self:UpdateNameplateVisibility(self.arWnd2Nameplate[idUnit])
  end
end

-- This function updates the visiblity of the provided nameplate, based on the visibility
-- and distance to the player. When the conditions are correct, we change the visibility.
function Cozmotronic:UpdateNameplateVisibility(tNameplate)
  local bNewShow = self:HelperVerifyVisibilityOptions(tNameplate) and (DistanceToUnit(tNameplate.unitOwner) <= self.tNamePlateOptions.nNameplateDistance)
  
  if bNewShow ~= tNameplate.bShow then
    tNameplate.wndNameplate:Show(bNewShow, false)
    tNameplate.bShow = bNewShow
  end
end

-- This function is called when the onscreen location changes for any unit.
-- Whenever this happens, we simply flag that unit as being "on screen" for our
-- Addon. This helps us minimize the amount of units we need to constantly check.
function Cozmotronic:OnWorldLocationOnScreen(wndHandler, wndControl, bOnScreen)
  local idUnit = wndHandler:GetId()
  
  if self.arWnd2Nameplate[idUnit] ~= nil then
    self.arWnd2Nameplate[idUnit].bOnScreen = bOnScreen
  end
end

-- This function draws the actual nameplate on screen.
-- The function keeps the entire nameplate and Addon configuration in mind when doing so,
-- as well as occlusion and distance of the nameplate compared to our player unit.
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
  elseif not unitOwner:IsMounted() and wndNameplate:GetUnit() ~= unitOwner then
    wndNameplate:SetUnit(unitOwner, self.tNamePlateOptions.nAnchor)
  end

  local bShowNameplate = (DistanceToUnit(tNameplate.unitOwner) <= self.tNamePlateOptions.nNameplateDistance) and self:HelperVerifyVisibilityOptions(tNameplate)
  
  wndNameplate:Show(bShowNameplate, false)
  
  if not bShowNameplate then
    return
  end
  
  if self.tNamePlateOptions.nXoffset or self.tNamePlateOptions.nYoffset then
    wndNameplate:SetAnchorOffsets(-15 + (self.tNamePlateOptions.nXoffset or 0), -15 + (self.tNamePlateOptions.nYoffset or 0), 15 + (self.tNamePlateOptions.nXoffset or 0), 15 + (self.tNamePlateOptions.nYoffset or 0))
  end
  
  if self.tNamePlateOptions.bScaleNameplates == true then
    if PerspectivePlates == nil then 
      PerspectivePlates = Apollo.GetAddon("PerspectivePlates")
    end
    
    if PerspectivePlates then
      PerspectivePlates:OnRequestedResize(tNameplate)
    else
      self:ScaleNameplate(tNameplate)
    end
  end
  
  self:DrawRPNamePlate(tNameplate)
end

-- This function draws the actual RP nameplate on top of the unit nameplate.
-- Again all checks are kept in mind as in the normal function.
function PDA:DrawRPNamePlate(tNameplate)
  local tRPColors, tCSColors
  local rpFullname, rpTitle, rpStatus
  local unitName = tNameplate.unitName
  local xmlNamePlate = XmlDoc:new()
  local wndNameplate = tNameplate.wndNameplate
  local wndData = wndNameplate:FindChild("wnd_Data")
  local btnRP = wndNameplate:FindChild("btn_RP")
  
  rpFullname = RPCore:GetTrait(unitName,"fullname") or unitName
  rpTitle = RPCore:FetchTrait(unitName,"title")
  rpStatus = RPCore:GetTrait(unitName, "rpflag")
  
  local strNameString = ""
  
  if self.tNamePlateOptions.bShowNames == true then
    strNameString = strNameString .. string.format("{name}%s{/name}\n", rpFullname)
    if self.tNamePlateOptions.bShowTitles == true and rpTitle ~= nil then
      strNameString = strNameString .. string.format("{title}%s{/title}", rpTitle)
    end 
  end
  
  local strNamePlate = GeminiRichText:ParseMarkup(strNameString, self.tStyles)

  wndData:SetAML(strNamePlate)
  wndData:SetHeightToContentHeight()
  
  if rpStatus == nil then rpStatus = 0 end
  
  local strState = RPCore:FlagsToString(rpStatus)
  local xmlTooltip = XmlDoc.new()
  
  xmlTooltip:StartTooltip(Tooltip.TooltipWidth)
  
  if self.tNamePlateOptions.bShowNames == false then
    xmlTooltip:AddLine(rpFullname, "FF009999", "CRB_InterfaceMedium_BO")
    if self.tNamePlateOptions.bShowTitles == true and rpTitle ~= nil then
      xmlTooltip:AddLine(rpTitle, "FF99FFFF", "CRB_InterfaceMedium_BO")
    end
    xmlTooltip:AddLine("――――――――――――――――――――", "FF99FFFF", "CRB_InterfaceMedium_BO")
  end
  
  xmlTooltip:AddLine(strState, self.tStateColors[rpStatus], "CRB_InterfaceMedium_BO")
  
  btnRP:SetTooltipDoc(xmlTooltip)
  btnRP:SetBGColor(self.tStateColors[rpStatus] or "FFFFFFFF")
end

---------------------------------------------------------------------------------------------------
-- wndError Functions
---------------------------------------------------------------------------------------------------
-- This function is called whenever the User clicks on the button of the error form.
-- When this happens, we will simply close the window and hide it from the User.
function Cozmotronic:onBtnCloseClick( wndHandler, wndControl, eMouseButton )
	self.wndError:Close()
end

---------------------------------------------------------------------------------------------------
-- wndMain Functions
---------------------------------------------------------------------------------------------------
-- This function is called whenever the User clicks on the Close button of the main window.
-- When this button is clicked, we simply close the form and do not save any information.
function Cozmotronic:OnClose(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
	self.wndMain:Close()
end

-- This function is called whenever the User clicks on the Info button of the main window.
-- When this button is clicked, we show the Info panel, displaying some additional debug
-- and helpful information.
function Cozmotronic:OnInfo(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
end

-- This function is called whenever the User clicks on the Save button of the main window.
-- When this button is clicked, we collect the information stored in the text fields
-- and save it in the Communicator Package as local traits.
function Cozmotronic:OnSave(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
  self:LoadAndStoreLocalTrait("Name")
  self:LoadAndStoreLocalTrait("Title")
  self:LoadAndStoreLocalTrait("Age")
  self:LoadAndStoreLocalTrait("Gender")
  self:LoadAndStoreLocalTrait("Height")
  self:LoadAndStoreLocalTrait("Weight")
  self:LoadAndStoreLocalTrait("Description")
  
  self:OnClose(wndHandler, wndControl, eMouseButton, nLastRelativeMouseX, nLastRelativeMouseY, bDoubleClick, bStopPropagation)
end

-- This function is called whenever the text inside one of the input fields changes.
-- The function will hide the underlying label, to make sure the text is properly readable
-- for the User.
function Cozmotronic:OnEditBoxChanged(wndHandler, wndControl, strText)
  if strText == nil or strText == "" then
    wndControl:FindChild("label"):Show(true)
  else
    wndControl:FindChild("label"):Show(false)
  end
end

-----------------------------------------------------------------------------------------------
-- Cozmotronic Instance
-----------------------------------------------------------------------------------------------
local CozmotronicInst = Cozmotronic:new()
CozmotronicInst:Init()
