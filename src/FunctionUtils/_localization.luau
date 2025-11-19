--!strict
--@author: crusherfire
--@date: 9/11/25
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------
local LocalizationService = game:GetService("LocalizationService")

-----------------------------
-- DEPENDENCIES --
-----------------------------

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

--[[
	Returns the string ID for the client's system locale (e.g. "en-us").
	Returns the server locale when called from server.
]]
function Module.getSystemLocale(): string
	return LocalizationService.SystemLocaleId
end

-----------------------------
-- MAIN --
-----------------------------
return Module