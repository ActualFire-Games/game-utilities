--!strict

type GuardPredicate = (descendant: any) -> (boolean)

local function defaultDescendantGuard(_descendant: Instance): boolean
	return true
end

--[=[
	Creates an observer that captures every descendant of the given instance.
	An optional guard predicate can filter which descendants trigger the observer.

	-- Only observe Parts anywhere under workspace.Model
	local stop = observeDescendants(
		workspace.Model,
		function(part)
			print("Part added:", part:GetFullName())
			return function()
				print("Part removed (or observer stopped):", part:GetFullName())
			end
		end,
		function(desc)
			return desc:IsA("BasePart")
		end
	)
]=]
local function observeDescendants(
	instance: any,
	callback: (descendant: any) -> (() -> ())?,
	guard: ( GuardPredicate )?
): () -> ()
	local descAddedConn: RBXScriptConnection
	local descRemovingConn: RBXScriptConnection
	local handledDescendant: { [Instance]: boolean } = {}
	-- Map each descendant to its cleanup function
	local cleanupPerDescendant: { [Instance]: () -> () } = {}

	-- Use provided guard or default
	local descendantGuard: GuardPredicate = if guard ~= nil then guard else defaultDescendantGuard

	-- When a new descendant appears
	local function OnDescendantAdded(descendant: Instance)
		if not descAddedConn.Connected then
			return
		end
		if handledDescendant[descendant] then
			-- already executed callback for this child
			return
		end
		handledDescendant[descendant] = true

		if not descendantGuard(descendant) then
			return
		end
		
		-- Run the callback in protected mode:
		local success, cleanup = xpcall(function(descendant)
			local clean = callback(descendant)
			if clean ~= nil then
				assert(typeof(clean) == "function", "callback must return a function or nil")
			end
			return clean
		end, debug.traceback, descendant :: any)

		-- If callback errored, print out the traceback:
		if not success then
			local err = ""
			local firstLine = string.split(cleanup :: any, "\n")[1]
			local lastColon = string.find(firstLine, ": ")
			if lastColon then
				err = firstLine:sub(lastColon + 1)
			end
			warn(`error while calling observeDescendants({instance}) callback:{err}\n{cleanup}`)
			return
		end
		
		if cleanup then
			-- only keep cleanup if still valid
			if descAddedConn.Connected and descendant:IsDescendantOf(instance) then
				cleanupPerDescendant[descendant] = cleanup
			else
				task.spawn(cleanup)
			end
		end
	end

	-- When a descendant is removed
	local function OnDescendantRemoving(descendant: Instance)
		handledDescendant[descendant] = nil
		local cleanup = cleanupPerDescendant[descendant]
		cleanupPerDescendant[descendant] = nil
		if typeof(cleanup) == "function" then
			task.spawn(cleanup)
		end
	end

	-- Connect the events
	descAddedConn = instance.DescendantAdded:Connect(OnDescendantAdded)
	descRemovingConn = instance.DescendantRemoving:Connect(OnDescendantRemoving)

	-- Initialize existing descendants
	for _, descendant in instance:GetDescendants() do
		task.defer(OnDescendantAdded, descendant)
	end

	-- Return a stop function
	return function()
		descAddedConn:Disconnect()
		descRemovingConn:Disconnect()

		-- Clean up any still-tracked descendants
		for descendant in pairs(cleanupPerDescendant) do
			OnDescendantRemoving(descendant)
		end
	end
end

return observeDescendants