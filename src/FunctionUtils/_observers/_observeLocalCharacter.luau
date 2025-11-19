--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--[=[
	@within Observers

	Observes the local player's character, similar to `observeCharacter` but client-only.

	```lua
	observeLocalCharacter(function(character)
		print("Local character spawned")

		return function()
			print("Local character removed")
		end
	end)
	```
]=]
local function observeLocalCharacter(callback: (character: Model) -> (() -> ())?): () -> ()
	assert(RunService:IsClient(), "observeLocalCharacter() is client-only!")
	local player = Players.LocalPlayer
	local handledCharacter = false
	local cleanupFn: (() -> ())? = nil
	local characterAddedConn: RBXScriptConnection

	local function onCharacterAdded(character: Model)
		if not characterAddedConn.Connected then
			return
		end
		if handledCharacter then
			return
		end
		handledCharacter = true
		local currentCharCleanup: (() -> ())? = nil
		
		local ancestryChangedConn: RBXScriptConnection
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
		local success, cleanup = xpcall(function(character)
			local clean = callback(character)
			if clean ~= nil then
				assert(typeof(clean) == "function", "callback must return a function or nil")
			end
			return clean
		end, debug.traceback, character :: any)

		-- If callback errored, print out the traceback:
		if not success then
			local err = ""
			local firstLine = string.split(cleanup :: any, "\n")[1]
			local lastColon = string.find(firstLine, ": ")
			if lastColon then
				err = firstLine:sub(lastColon + 1)
			end
			warn(`error while calling observeLocalCharacter() callback:{err}\n{cleanup}`)
			return
		end
		
		if cleanup then
			if characterAddedConn.Connected and character.Parent then
				currentCharCleanup = cleanup
				cleanupFn = cleanup
			else
				task.spawn(cleanup)
			end
		end
	end

	characterAddedConn = player.CharacterAdded:Connect(onCharacterAdded)

	if player.Character then
		task.defer(onCharacterAdded, player.Character)
	end

	return function()
		characterAddedConn:Disconnect()
		if cleanupFn ~= nil then
			task.spawn(cleanupFn)
			cleanupFn = nil
		end
	end
end

return observeLocalCharacter