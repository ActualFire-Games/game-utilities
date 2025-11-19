--!strict

local function defaultValueGuard(_value: any): boolean
	return true
end

--[=[
	@within Observers

	Creates an observer around a property of a given instance.
	An optional `guard` predicate can be supplied to filter which values trigger the observer.

	```lua
	-- Only observe Name changes when they’re non-empty strings
	local stop = observeProperty(
		workspace.Model,
		"Name",
		function(newName: string)
			print("New name:", newName)
			return function()
				print("Name changed away from:", newName)
			end
		end,
		function(value)
			return typeof(value) == "string" and #value > 0
		end
	)
	```

	Returns a function that stops observing and runs any outstanding cleanup.
]=]
local function observeProperty(
	instance: Instance,
	propertyName: string,
	callback: (value: any) -> ( () -> () )?,
	guard: ((value: any) -> boolean)?
): () -> ()
	local cleanFn: (() -> ())?
	local propChangedConn: RBXScriptConnection
	local changeCounter = 0

	-- decide which guard to use
	local valueGuard: (value: any) -> boolean = if guard ~= nil then guard else defaultValueGuard

	local function onPropertyChanged()
		if not propChangedConn.Connected then
			return
		end
		
		-- run previous cleanup (if any)
		if cleanFn then
			task.spawn(cleanFn)
			cleanFn = nil
		end
		
		local newValue = (instance :: any)[propertyName]
		changeCounter += 1
		local currentId = changeCounter
		
		if not valueGuard(newValue) then
			return
		end
		
		-- Run the callback in protected mode:
		local success, cleanup = xpcall(function(newValue)
			local clean = callback(newValue)
			if clean ~= nil then
				assert(typeof(clean) == "function", "callback must return a function or nil")
			end
			return clean
		end, debug.traceback, newValue :: any)

		-- If callback errored, print out the traceback:
		if not success then
			local err = ""
			local firstLine = string.split(cleanup :: any, "\n")[1]
			local lastColon = string.find(firstLine, ": ")
			if lastColon then
				err = firstLine:sub(lastColon + 1)
			end
			warn(`error while calling observeProperty("{propertyName}") callback:{err}\n{cleanup}`)
			return
		end
		
		if currentId == changeCounter and propChangedConn.Connected then
			cleanFn = cleanup
		elseif cleanup then
			-- otherwise run it immediately
			task.spawn(cleanup)
		end
	end
	
	-- connect to the property‑changed signal
	propChangedConn = instance:GetPropertyChangedSignal(propertyName):Connect(onPropertyChanged)

	-- fire once on startup
	task.defer(onPropertyChanged)

	-- return stop function
	return function()
		propChangedConn:Disconnect()
		if cleanFn then
			task.spawn(cleanFn)
			cleanFn = nil
		end
	end
end

return observeProperty