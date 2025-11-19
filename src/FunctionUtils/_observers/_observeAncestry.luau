--!strict

type GuardPredicate = (
	changed: Instance,
	newParent: Instance?
) -> boolean

local function defaultAncestryGuard(
	_changed: Instance,
	_newParent: Instance?
): boolean
	return true
end

--[=[
	@within Observers

	Observes when an instance's ancestry changes.
	Observer will not be called if the ancestry becomes nil.

	Returns a function that stops observing and runs any outstanding cleanup.
]=]
local function observeAncestry(
	instance: any,
	callback: (
		changed: Instance,
		newParent: Instance?
	) -> (() -> ())?,
	guard: GuardPredicate?
): () -> ()
	assert(typeof(instance) == "Instance", "Bad argument #1 to observeAncestry, expected Instance")

	-- choose the guard (default always true)
	local ancestryGuard: GuardPredicate = guard or defaultAncestryGuard

	-- holds the cleanup function from the last callback
	local cleanupFunction: (() -> ())?
	local connection: RBXScriptConnection

	local function onAncestryChanged(
		changed: Instance,
		newParent: Instance?
	)
		if not connection.Connected then
			return
		end
		-- run previous cleanup, if any
		if cleanupFunction then
			task.spawn(cleanupFunction)
			cleanupFunction = nil
		end

		-- skip if the changed instance is no longer in DataModel
		if not changed:IsDescendantOf(game) then
			return
		end

		-- skip if guard rejects this change
		if not ancestryGuard(changed, newParent) then
			return
		end
		
		-- Run the callback in protected mode:
		local success, cleanup = xpcall(function(changed, newParent)
			local clean = callback(changed, newParent)
			if clean ~= nil then
				assert(typeof(clean) == "function", "callback must return a function or nil")
			end
			return clean
		end, debug.traceback, changed :: any, newParent :: any)

		-- If callback errored, print out the traceback:
		if not success then
			local err = ""
			local firstLine = string.split(cleanup :: any, "\n")[1]
			local lastColon = string.find(firstLine, ": ")
			if lastColon then
				err = firstLine:sub(lastColon + 1)
			end
			warn(`error while calling observeAncestry({instance}) callback:{err}\n{cleanup}`)
			return
		end
		
		if cleanup then
			if connection.Connected then
				cleanupFunction = cleanup
			else
				task.spawn(cleanup)
			end
		end
	end

	-- hook up the AncestryChanged event
	connection = instance.AncestryChanged:Connect(onAncestryChanged)

	-- seed with the instance's current parent
	task.defer(onAncestryChanged, instance, instance.Parent)

	-- return a stopper
	return function()
		if connection.Connected then
			connection:Disconnect()
		end

		if cleanupFunction then
			task.spawn(cleanupFunction)
			cleanupFunction = nil
		end
	end
end

return observeAncestry
