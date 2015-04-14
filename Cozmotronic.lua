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
	[GameLib.CodeEnumRace.Mechari] = Apollo.GetString("RaceMechari"),
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
		
		-- Create the required tabs
		local wndBiography = Apollo.LoadForm(self.xmlDoc, "CozmotronicForm", nil, self)
		local wndOptions = Apollo.LoadForm(self.xmlDoc, "CozmotronicForm", nil, self)
		
		-- Configure the tabs
		wndBiography:SetText("Biography")
		wndOptions:SetText("Options")
		
		-- Fire the windows management event.
		Event_FireGenericEvent("WindowManagementAdd", {wnd = wndBiography, strName = "Biography", bIsTabWindow = true})
		Event_FireGenericEvent("WindowManagementAdd", {wnd = wndOptions, strName = "Options", bIsTabWindow = true})		
		
		-- Inject the tabs
		self.wndMain:AttachTab(wndBiography, true)
		self.wndMain:AttachTab(wndOptions, true)
		
		-- Show the form
	    self.wndMain:Show(true)

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

-----------------------------------------------------------------------------------------------
-- Cozmotronic Instance
-----------------------------------------------------------------------------------------------
local CozmotronicInst = Cozmotronic:new()
CozmotronicInst:Init()
