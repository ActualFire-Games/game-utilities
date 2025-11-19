--!strict

local CollectionService = game:GetService("CollectionService")

type InstanceStatus = "startup" | "dead" | "active"

--[=[
	@within Observers

	Creates an observer around a CollectionService tag. The given callback will fire for each instance
	that has the given tag.

	The callback should return a function, which will be called when the given instance's tag is either
	destroyed, loses the given tag, or (if the `ancestors` table is provided) goes outside of the allowed
	ancestors.

	The function itself returns a function that can be called to stop the observer. This will also call
	any cleanup functions of currently-observed instances.

	```lua
	local stopObserver = Observers.observeTag("MyTag", function(instance: Instance)
		print("Observing", instance)

		-- The "cleanup" function:
		return function()
			print("Stopped observing", instance)
		end
	end)

	-- Optionally, the `stopObserver` function can be called to completely stop the observer:
	task.wait(10)
	stopObserver()
	```

	#### Ancestor Inclusion List
	By default, the `observeTag` function will observe a tagged instance anywhere in the Roblox game
	hierarchy. The `ancestors` table can optionally be used, which will restrict the observer to only
	observe tagged instances that are descendants of instances within the `ancestors` table.

	For instance, if a tagged instance should only be observed when it is in the Workspace, the Workspace
	can be added to the `ancestors` list. This might be useful if a tagged model prefab exist somewhere
	such as ServerStorage, but shouldn't be observed until placed into the Workspace.

	```lua
	local allowedAncestors = { workspace }

	Observers.observeTag(
		"MyTag",
		function(instance: Instance)
			...
		end,
		allowedAncestors
	)
	```
]=]
function observeTag<T>(tag: string, callback: (instance: T) -> (() -> ())?, ancestors: { any }?): () -> ()
	local instances: { [Instance]: InstanceStatus } = {}
	local cleanups: { [Instance]: () -> () } = {}
	local ancestryConn: { [Instance]: RBXScriptConnection } = {}

	local onInstAddedConn: RBXScriptConnection
	local onInstRemovedConn: RBXScriptConnection

	local function isGoodAncestor(instance: Instance)
		if instance.Parent == nil then
			-- :IsDescendantOf(game) is slower than Parent check
			return false
		end
		
		if ancestors == nil then
			return true
		end

		for _, ancestor in ancestors do
			if instance:IsDescendantOf(ancestor) then
				return true
			end
		end

		return false
	end
	
	local function attemptCleanup(instance: Instance)
		local cleanup = cleanups[instance]
		cleanups[instance] = nil
		
		-- If we've got non-nil parent, we're probably dead
		instances[instance] = if instance.Parent then "dead" else nil :: any
		
		if cleanup then
			task.spawn(cleanup)
		end
	end
	
	local function attemptStartup(instance: Instance)
		instances[instance] = "startup"
		
		task.spawn(function()
			-- Protected mode:
			local success, errOrCleanup = xpcall(function(inst: T)
				local clean = callback(inst)
				if clean ~= nil then
					assert(typeof(clean) == "function", "callback must return a function or nil")
				end
				return clean
			end, debug.traceback, instance :: any)
			
			local stillStartup = instances[instance] == "startup"
			
			if stillStartup then
				instances[instance] = "active"
			end
			
			if not success then
				-- If callback errored, print out the traceback:
				local err = ""
				local firstLine = string.split(errOrCleanup :: any, "\n")[1]
				local lastColon = string.find(firstLine, ": ")
				if lastColon then
					err = firstLine:sub(lastColon + 1)
				end
				warn(`error while calling observeTag("{tag}") callback:{err}\n{errOrCleanup}`)
				return
			end
			
			if stillStartup then
				cleanups[instance] = errOrCleanup :: any
			elseif errOrCleanup then
				-- immediately call cleanup
				task.spawn(errOrCleanup)
			end
		end)
	end

	local function onAncestryChanged(instance: Instance)
		local good = isGoodAncestor(instance)
		
		if
			good
			and instances[instance] == "dead"
		then
			-- we can try to observe
			attemptStartup(instance)
		elseif not good then
			-- we need to stop observing
			attemptCleanup(instance)
		end
	end

	local function onInstanceAdded(instance: Instance)
		if instances[instance] then
			-- already observed
			return
		end
		
		instances[instance] = "dead"
		
		if ancestors then
			ancestryConn[instance] = instance.AncestryChanged:Connect(function()
				onAncestryChanged(instance)
			end)
		end
		onAncestryChanged(instance)
	end
	
	local function onInstanceRemoved(instance: Instance)
		attemptCleanup(instance)
		
		local conn = ancestryConn[instance]
		if conn then
			conn:Disconnect()
			ancestryConn[instance] = nil
		end
		instances[instance] = nil
	end
	
	-- Hook up added/removed listeners for the given tag:
	onInstAddedConn = CollectionService:GetInstanceAddedSignal(tag):Connect(onInstanceAdded)
	onInstRemovedConn = CollectionService:GetInstanceRemovedSignal(tag):Connect(onInstanceRemoved)

	-- Attempt to mark already-existing tagged instances right away:
	for _, instance in CollectionService:GetTagged(tag) do
		task.defer(onInstanceAdded, instance)
	end

	-- Full observer cleanup function:
	return function()
		onInstAddedConn:Disconnect()
		onInstRemovedConn:Disconnect()

		-- Clear all instances:
		local instance = next(instances)
		while instance do
			onInstanceRemoved(instance)
			instance = next(instances)
		end
	end
end

return observeTag