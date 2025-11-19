--!strict
--@author: crusherfire
--@date: 9/24/25
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local t = require("./_t")

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
	Returns a string identifying the calling function, otherwise, falls back to "source:line"
]]
function Module.getFunctionLabel(): string
	local name = debug.info(2, "n")
	if name ~= nil and name ~= "" then
		return name
	end
	
	local source = debug.info(2, "s") or "unknown"
	local line = debug.info(2, "l") or -1
	return `{source}:{line}`
end

-----------------------------
-- MAIN --
-----------------------------
return Module