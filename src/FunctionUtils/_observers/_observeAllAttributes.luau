--!strict

type GuardPredicate = (attributeName: string, value: any) -> (boolean)

local function defaultGuard(_attributeName: string, _value: any): boolean
	return true
end

--[=[
	Creates an observer that watches all attributes on a given instance.
	Your callback is invoked for existing attributes on start and
	for every subsequent change where guard(attributeName, value) returns true.

	-- Only observe numeric attributes
	local stop = observeAllAttributes(
		workspace.Part,
		function(name, value)
			print(name, "=", value)
			return function()
				print(name, "was removed or no longer passes guard")
			end
		end,
		function(name, value)
			return typeof(value) == "number"
		end
	)
	
	Returns a function that stops observing and runs any outstanding cleanup callbacks.
]=]
local function observeAllAttributes(
	instance: any,
	callback: (attributeName: string, value: any) -> (() -> ())?,
	guardPredicate: (GuardPredicate)?
): () -> ()
	local cleanupFunctionsPerAttribute: { [string]: () -> () } = {}
	local changeIds: { [string]: number } = {}
	local attributeGuard: GuardPredicate = if guardPredicate ~= nil then guardPredicate else defaultGuard
	local attributeChangedConnection: RBXScriptConnection
	
	local function onAttributeChanged(attributeName: string)
		if not attributeChangedConnection.Connected then
			return
		end
		-- Tear down any prior callback for this attribute
		local previousCleanup = cleanupFunctionsPerAttribute[attributeName]
		if typeof(previousCleanup) == "function" then
			task.spawn(previousCleanup)
			cleanupFunctionsPerAttribute[attributeName] = nil
		end
		
		if not changeIds[attributeName] then
			changeIds[attributeName] = 0
		end
		changeIds[attributeName] += 1
		local id = changeIds[attributeName]
		
		-- Fire new callback if guard passes
		local newValue = instance:GetAttribute(attributeName)
		
		if newValue == nil or not attributeGuard(attributeName, newValue) then
			return
		end
		
		-- Run the callback in protected mode:
		local success, cleanup = xpcall(function(attributeName, newValue)
			local clean = callback(attributeName, newValue)
			if clean ~= nil then
				assert(typeof(clean) == "function", "callback must return a function or nil")
			end
			return clean
		end, debug.traceback, attributeName :: any, newValue :: any)

		-- If callback errored, print out the traceback:
		if not success then
			local err = ""
			local firstLine = string.split(cleanup :: any, "\n")[1]
			local lastColon = string.find(firstLine, ": ")
			if lastColon then
				err = firstLine:sub(lastColon + 1)
			end
			warn(`error while calling observeAllAttributes({instance}) callback:{err}\n{cleanup}`)
			return
		end
		
		if cleanup then
			-- Only keep it if we're still connected and the value hasn't changed again
			if attributeChangedConnection.Connected and changeIds[attributeName] == id then
				cleanupFunctionsPerAttribute[attributeName] = cleanup
			else
				task.spawn(cleanup)
			end
		end
	end

	-- Connect the global AttributeChanged event
	attributeChangedConnection = instance.AttributeChanged:Connect(onAttributeChanged)

	-- Seed with existing attributes
	for name, _ in instance:GetAttributes() do
		task.defer(onAttributeChanged, name)
	end

	-- Return a stopper that disconnects and cleans up everything
	return function()
		attributeChangedConnection:Disconnect()
		for name, cleanup in pairs(cleanupFunctionsPerAttribute) do
			cleanupFunctionsPerAttribute[name] = nil
			if typeof(cleanup) == "function" then
				task.spawn(cleanup)
			end
		end
	end
end

return observeAllAttributes