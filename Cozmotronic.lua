-----------------------------------------------------------------------------------------------
-- Client Lua Script for Cozmotronic
-- Copyright (c) NCsoft. All rights reserved
----------------------------------------------------------------------------------------------- 
require "Window"
 
-----------------------------------------------------------------------------------------------
-- Cozmotronic Module Definition
-----------------------------------------------------------------------------------------------
local Cozmotronic = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
local karRaceToString = {
	[GameLib.CodeEnumRace.Human] = Apollo.GetString("RaceHuman"),
	[GameLib.CodeEnumRace.Granok] = Apollo.GetString("RaceGranok"),
	[GameLib.CodeEnumRace.Aurin] = Apollo.GetString("RaceAurin"),
	[GameLib.CodeEnumRace.Draken] = Apollo.GetString("RaceDraken"),
	[GameLib.CodeEnunRace.Mechari] = Apollo.GetString("RaceMechari"),
	[GameLib.CodeEnumRace.Chua] = Apollo.GetString("RaceChua"),
	[GameLib.CodeEnumRace.Mordesh] = Apollo.GetString("CRB_Mordesh")
}

local karGenderToString = {
	[0] = Apollo.GetString("CRB_Male"),
	[1] = Apollo.GetString("CRB_Female"),
	[2] = Apollo.GetString("CRN_UnknownType")
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

-- Calculates the distance to the given unit.
local function DistanceToUnit(unitTarget)	
	local unitPlayer = GameLib.GetPlayerUnit()
	
	if type(unitTarget) == "string" then
		unitTarget = GameLib.GetPlayerUnitByName(tostring(unitTarget))
	end
	
	if not unitTarget or not unitPlayer then
		return 0
	end

	tPosTarget = unitTarget:GetPosition()
	tPosPlayer = unitPlayer:GetPosition()

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
	self.tPlayers = {}							-- Used for tracking all players in the channel.
	self.tOptions = {}							-- Used for tracking all our RP options.
	self.tDisplayOptions = {}					-- Used for temporarely storing the RP options of another player.
	self.tSettings = {}							-- Used for storing the Cozmotronic Configuration.
	self.tNameplateOptions = {}					-- Used for storing the Nameplate configuration.
	self.arUnit2Nameplate = {}					-- Tracking all UnitIds for the Nameplates
	self.arWnd2Nameplate = {}					-- Tracking all WindowIds for the Nameplates
	self.bHideAllNameplates = false				-- By default we do not hide nameplates.
	self.unitPlayer = GameLib.GetPlayerUnit()	-- Track ourselves.

    return o
end

function Cozmotronic:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- Cozmotronic OnLoad
-----------------------------------------------------------------------------------------------
function Cozmotronic:OnLoad()
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("Cozmotronic.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

-----------------------------------------------------------------------------------------------
-- Cozmotronic OnDocLoaded
-----------------------------------------------------------------------------------------------
function Cozmotronic:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "CozmotronicForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("cozmo", "OnCozmotronicOn", self)


		-- Do additional Addon initialization here
	end
end

-----------------------------------------------------------------------------------------------
-- Cozmotronic Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/cozmo"
function Cozmotronic:OnCozmotronicOn()
	self.wndMain:Invoke() -- show the window
end


-----------------------------------------------------------------------------------------------
-- CozmotronicForm Functions
-----------------------------------------------------------------------------------------------

-- when the Close button is clicked
function Cozmotronic:OnClose()
	self.wndMain:Close() -- hide the window
end


---------------------------------------------------------------------------------------------------
-- OverheadForm Functions
---------------------------------------------------------------------------------------------------

-- Verifies the VisbilityOptions for the specified Nameplate.
function Cozmotronic:VerifyVisibilityOptions(tNameplate)
	local unitOwner = tNameplate.unitOwner
	local bHiddenUnit = not unitOwner:ShouldShowNamePlate()
	
	-- If the unit is hidden, return false to not draw the nameplate.
	if bHiddenUnit then
		return false
	end
	
	-- If the nameplate is occluded, or the unit is not onscreen, return false
	-- to not draw the nameplate.
	if tNameplate.bOccluded or not tNameplate.bOnScreen then
		return false
	end
	
	-- Return true if it's our own nameplate and needs to be shown.
	if unitOwner:IsThePlayer() then
		return self.tNameplateOptions.bShowMyNameplate
	end
	
	-- If we need to show the target's nameplate, check if we're dealing with the
	-- target.
	if self.tNameplateOptions.bShowTargetNameplate == true then
		return GameLib.GetTargetUnit() == unitOwner
	end
	
	-- We're not sure what nameplate it is, so let's just draw it.
	return true
end

-- Gets called every time the UnitOcclusion changed in the client.
-- Will check whether the visibility of our nameplate needs to be changed.
function Cozmotronic:OnUnitOcclusionChanged( wndHandler, wndControl, bOccluded )
	local idUnit = wndHandler:GetId()
	
	if self.arWnd2Nameplate[idUnit] ~= nil then
		self.arWnd2Nameplate[idUnit].bOccluded = bOccluded
		self:UpdateNameplateVisibility(self.arWnd2Nameplate[idUnit])
	end
end

-- Updates the visibility of the supplied nameplate, based on the distance and the
-- visbility options configured in Cozmotronic.
function Cozmotronic:UpdateNameplateVisibility(tNameplate)
	local bNewShow = self:VerifyVisibilityOptions(tNameplate) 
					and (DistanceToUnit(tNameplate.unitOwner) <= self.tNamePlateOptions.nNameplateDistance
	
	if bNewShow ~= tNameplate.bShow then
		tNameplate.wndNameplate:Show(bNewShow, false)
		tNameplate.bShow = bNewShow
	end	
end

-- Gets called every time the WorldLocationOnScreen event is triggered.
-- Determines the flag whether the nameplate is onScreen or not.
function Cozmotronic:OnWorldLocationOnScreen( wndHandler, wndControl, bOnScreen )
	local idUnit = wndHandler:GetId()
	
	if self.arWnd2Nameplate[idUnit] ~= nil then
		self.arWnd2Nameplate[idUnit].bOnScreen = bOnScreen
	end
end

-- Draws the specified nameplate on the screen.
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

	local bShowNameplate = (DistanceToUnit(tNameplate.unitOwner) <= self.tNamePlateOptions.nNameplateDistance) and self:VerifyVisibilityOptions(tNameplate)
	
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

-- Draws the RP Nameplate for the Addon, using the provided information.
function Cozmotronic:DrawRPNamePlate(tNameplate)
	local tRPColors, tCSColors
	local rpFullname, rpTitle, rpStatus
	local unitName = tNameplate.unitName
	local xmlNamePlate = XmlDoc:new()
	local wndNameplate = tNameplate.wndNameplate
	local wndData = wndNameplate:FindChild("wnd_Data")
	local btnRP = wndNameplate:FindChild("btn_RP")
	
	-- TODO: Implement communication to get information.
	--rpFullname = RPCore:GetTrait(unitName,"fullname") or unitName
	--rpTitle = RPCore:FetchTrait(unitName,"title")
	--rpStatus = RPCore:GetTrait(unitName, "rpflag")
	
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
		
		xmlTooltip:AddLine("????????????????????", "FF99FFFF", "CRB_InterfaceMedium_BO")
	end

	xmlTooltip:AddLine(strState, self.tStateColors[rpStatus], "CRB_InterfaceMedium_BO")
	btnRP:SetTooltipDoc(xmlTooltip)
	btnRP:SetBGColor(self.tStateColors[rpStatus] or "FFFFFFFF")
end

-- Scales the selected nameplate, rendering it properly on screen.
function Cozmotronic:ScaleNameplate(tNameplate)
	if tNameplate.unitOwner:IsThePlayer() then return end

	local wndNameplate = tNameplate.wndNameplate
	local nDistance = DistanceToUnit(tNameplate.unitOwner)
	local fDistancePercentage = ((self.tNamePlateOptions.nNameplateDistance / nDistance) - 0.5)
	
	if fDistancePercentage > 1 then
		fDistancePercentage = 1
	end
	
	wndNameplate:SetScale(fDistancePercentage)
end

-- Refreshes the nameplates we have drawn onscreen, updating their information.
function Cozmotronic:RefreshPlates()
	for idx, tNameplate in pairs(self.arUnit2Nameplate) do
		if self.bHideAllNameplates == true then
			tNameplate.wndNameplate:Show(false, false)
			tNameplate.bShow = false
		else
			local bNewShow = self:HelperVerifyVisibilityOptions(tNameplate) and (DistanceToUnit(tNameplate.unitOwner) <= self.tNamePlateOptions.nNameplateDistance)

			if bNewShow ~= tNameplate.bShow then
				tNameplate.wndNameplate:Show(bNewShow, false)
				tNameplate.bShow = bNewShow
			end
			
			self:DrawNameplate(tNameplate)
		end
	end
end

-----------------------------------------------------------------------------------------------
-- Cozmotronic Instance
-----------------------------------------------------------------------------------------------
local CozmotronicInst = Cozmotronic:new()
CozmotronicInst:Init()
