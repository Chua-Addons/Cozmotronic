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
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function Cozmotronic:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here

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


-----------------------------------------------------------------------------------------------
-- Cozmotronic Instance
-----------------------------------------------------------------------------------------------
local CozmotronicInst = Cozmotronic:new()
CozmotronicInst:Init()
