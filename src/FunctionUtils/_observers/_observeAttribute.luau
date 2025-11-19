--!strict
local function defaultGuard(_value: any)
	return true
end

--[=[
	@within Observers

	Creates an observer around an attribute of a given instance. The callback will fire for any non-nil
	attribute value.

	```lua
	observeAttribute(workspace.Model, "MyAttribute", function(value)
		print("MyAttribute is now:", value)

		return function()
			-- Cleanup
			print("MyAttribute is no longer:", value)
		end
	end)
	```

	An optional `guard` predicate function can be supplied to further narrow which values trigger the observer.
	For instance, if only strings are wanted:

	```lua
	observeAttribute(
		workspace.Model,
		"MyAttribute",
		function(value) print("value is a string", value) end,
		function(value) return typeof(value) == "string" end
	)
	```

	The observer also returns a function that can be called to clean up the observer:
	```lua
	local stopObserving = observeAttribute(workspace.Model, "MyAttribute", function(value) ... end)

	task.wait(10)
	stopObserving()
	```
]=]
local function observeAttribute(
	instance: any,
	name: string,
	callback: (value: any) -> ( () -> () )?,
	guard: ((value: any) -> boolean)?
): () -> ()
	local cleanFn: (() -> ())? = nil

	local onAttrChangedConn: RBXScriptConnection
	local changedId = 0
	local valueGuard: (value: any) -> boolean = if guard ~= nil then guard else defaultGuard

	local function OnAttributeChanged()
		if not onAttrChangedConn.Connected then
			return
		end
		
		if cleanFn ~= nil then
			task.spawn(cleanFn)
			cleanFn = nil
		end
		
		local value = instance:GetAttribute(name)
		changedId += 1
		local id = changedId
		
		if value == nil or not valueGuard(value) then
			return
		end
		
		-- Run the callback in protected mode:
		local success, cleanup = xpcall(function(value)
			local clean = callback(value)
			if clean ~= nil then
				assert(typeof(clean) == "function", "callback must return a function or nil")
			end
			return clean
		end, debug.traceback, value :: any)

		-- If callback errored, print out the traceback:
		if not success then
			local err = ""
			local firstLine = string.split(cleanup :: any, "\n")[1]
			local lastColon = string.find(firstLine, ": ")
			if lastColon then
				err = firstLine:sub(lastColon + 1)
			end
			warn(`error while calling observeAttribute("{name}") callback:{err}\n{cleanup}`)
			return
		end
		
		if cleanup then
			if id == changedId and onAttrChangedConn.Connected then
				cleanFn = cleanup
			else
				task.spawn(cleanup)
			end
		end
	end

	-- Get changed values:
	onAttrChangedConn = instance:GetAttributeChangedSignal(name):Connect(OnAttributeChanged)

	-- Get initial value:
	task.defer(OnAttributeChanged)

	-- Cleanup:
	return function()
		onAttrChangedConn:Disconnect()
		if cleanFn ~= nil then
			task.spawn(cleanFn)
			cleanFn = nil
		end
	end
end

return observeAttribute