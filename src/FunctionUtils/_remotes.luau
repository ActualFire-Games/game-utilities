--!strict
--@author: crusherfire
--@date: 1/30/25
--[[@description:
	Utility functions for remotes/remote related utility.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local _game = require("./_game")

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

function Module.fireToAllClientsExcept(exception: { Player }, remote: RemoteEvent, ...: any)
	local players = _game.getPlayerList(exception)
	for _, player in players do
		remote:FireClient(player, ...)
	end
end

-----------------------------
-- MAIN --
-----------------------------
return Module