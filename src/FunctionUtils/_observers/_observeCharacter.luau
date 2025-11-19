--!strict

local observePlayer = require(script.Parent._observePlayer)

--[=[
	@within Observers

	Creates an observer that captures each character in the game.

	```lua
	observeCharacter(function(player, character)
		print("Character spawned for " .. player.Name)

		return function()
			-- Cleanup
			print("Character removed for " .. player.Name)
		end
	end)
	```
]=]
local function observeCharacter(callback: (player: Player, character: Model) -> (() -> ())?): () -> ()
	return observePlayer(function(player)
		local cleanupFn: (() -> ())? = nil
		local handledCharacter = false
		local characterAddedConn: RBXScriptConnection
		local ancestryChangedConn: RBXScriptConnection

		local function OnCharacterAdded(character: Model)
			if not characterAddedConn.Connected then
				return
			end
			if handledCharacter then
				return
			end
			handledCharacter = true
			local currentCharCleanup: (() -> ())? = nil
			
			if ancestryChangedConn then
				-- disconnect any previous (just incase)
				ancestryChangedConn:Disconnect()
			end
			
			-- Watch for the character to be removed from the game hierarchy:
			ancestryChangedConn = character.AncestryChanged:Connect(function(_, newParent)
				if newParent == nil and ancestryChangedConn.Connected then
					handledCharacter = false
					ancestryChangedConn:Disconnect()
					if currentCharCleanup ~= nil then
						task.spawn(currentCharCleanup)
						if cleanupFn == currentCharCleanup then
							cleanupFn = nil
						end
						currentCharCleanup = nil
					end
				end
			end)
			
			-- Run the callback in protected mode:
			local success, cleanup = xpcall(function(player, character)
				local clean = callback(player, character)
				if clean ~= nil then
					assert(typeof(clean) == "function", "callback must return a function or nil")
				end
				return clean
			end, debug.traceback, player :: any, character :: any)

			-- If callback errored, print out the traceback:
			if not success then
				local err = ""
				local firstLine = string.split(cleanup :: any, "\n")[1]
				local lastColon = string.find(firstLine, ": ")
				if lastColon then
					err = firstLine:sub(lastColon + 1)
				end
				warn(`error while calling observeCharacter() callback:{err}\n{cleanup}`)
				return
			end

			if cleanup then
				if characterAddedConn.Connected and character.Parent then
					currentCharCleanup = cleanup
					cleanupFn = cleanup
				else
					-- Character is already gone or observer has stopped; call cleanup immediately:
					task.spawn(cleanup)
				end
			end
		end

		-- Handle character added:
		characterAddedConn = player.CharacterAdded:Connect(OnCharacterAdded)

		-- Handle initial character:
		if player.Character then
			task.defer(OnCharacterAdded, player.Character)
		end

		-- Cleanup:
		return function()
			characterAddedConn:Disconnect()
			if ancestryChangedConn then
				ancestryChangedConn:Disconnect()
			end
			if cleanupFn ~= nil then
				task.spawn(cleanupFn)
				cleanupFn = nil
			end
		end
	end)
end

return observeCharacter