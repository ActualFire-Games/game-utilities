--!strict

local Players = game:GetService("Players")

--[=[
	@within Observers

	Creates an observer that captures each player in the game.

	```lua
	observePlayer(function(player)
		print("Player entered game", player.Name)

		return function()
			-- Cleanup
			print("Player left game (or observer stopped)", player.Name)
		end
	end)
	```
]=]
local function observePlayer(callback: (player: Player) -> (() -> ())?): () -> ()
	local playerAddedConn: RBXScriptConnection
	local playerRemovingConn: RBXScriptConnection
	local handledPlayer: { [Player]: boolean } = {}
	local cleanupsPerPlayer: { [Player]: () -> () } = {}

	local function OnPlayerAdded(player: Player)
		if not playerAddedConn.Connected then
			return
		end
		if handledPlayer[player] then
			return
		end
		handledPlayer[player] = true
		
		-- Run the callback in protected mode:
		local success, cleanup = xpcall(function(player)
			local clean = callback(player)
			if clean ~= nil then
				assert(typeof(clean) == "function", "callback must return a function or nil")
			end
			return clean
		end, debug.traceback, player :: any)

		-- If callback errored, print out the traceback:
		if not success then
			local err = ""
			local firstLine = string.split(cleanup :: any, "\n")[1]
			local lastColon = string.find(firstLine, ": ")
			if lastColon then
				err = firstLine:sub(lastColon + 1)
			end
			warn(`error while calling observePlayer() callback:{err}\n{cleanup}`)
			return
		end
		
		if cleanup then
			if playerAddedConn.Connected and player.Parent then
				cleanupsPerPlayer[player] = cleanup
			else
				task.spawn(cleanup)
			end
		end
	end

	local function OnPlayerRemoving(player: Player)
		handledPlayer[player] = nil
		local cleanup = cleanupsPerPlayer[player]
		cleanupsPerPlayer[player] = nil
		if typeof(cleanup) == "function" then
			task.spawn(cleanup)
		end
	end

	-- Listen for changes:
	playerAddedConn = Players.PlayerAdded:Connect(OnPlayerAdded)
	playerRemovingConn = Players.PlayerRemoving:Connect(OnPlayerRemoving)

	-- Initial:
	for _, player in Players:GetPlayers() do
		task.defer(OnPlayerAdded, player)
	end

	-- Cleanup:
	return function()
		playerAddedConn:Disconnect()
		playerRemovingConn:Disconnect()

		local player = next(cleanupsPerPlayer)
		while player do
			OnPlayerRemoving(player)
			player = next(cleanupsPerPlayer)
		end
	end
end

return observePlayer