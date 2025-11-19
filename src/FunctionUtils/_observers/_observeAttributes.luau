--!strict

type GuardPredicate = (attributeName: string, value: any) -> boolean

local function defaultGuard(_attributeName: string, _value: any): boolean
	return true
end

--[=[
	@within Observers

	Watches a selected list of attributes on an instance.
	The callback runs for each named attribute whenever its value is non-nil and passes the guard.
	On start, it also fires once for any of the listed attributes that already exist and pass the guard.

	```lua
	local stop = observeAttributes(
		workspace.Part,
		{ "Health", "Mana", "PowerUp" },
		function(name, value)
			print(name, "=", value)
			return function()
				print("Stopped watching", name, "value:", value)
			end
		end,
		function(name, value)
			return typeof(value) == "number"
		end
	)

	task.wait(10)
	stop()
	```

	Returns a function that disconnects all listeners and runs outstanding cleanup callbacks.
]=]
local function observeAttributes(
	instance: any,
	attributeNames: { string },
	callback: (attributeName: string, value: any) -> (() -> ())?,
	guardPredicate: (GuardPredicate)?
): () -> ()
	-- Deduplicate the provided names to avoid double connections
	local namesSet: { [string]: boolean } = {}
	for _, name in attributeNames do
		if typeof(name) == "string" and name ~= "" then
			namesSet[name] = true
		end
	end

	local cleanupPerAttribute: { [string]: (() -> ())? } = {}
	local changeIds: { [string]: number } = {}
	local connections: { [string]: RBXScriptConnection } = {}
	local attributeGuard: GuardPredicate = if guardPredicate ~= nil then guardPredicate else defaultGuard

	local function onAttributeChanged(attributeName: string)
		local connection = connections[attributeName]
		if connection == nil then
			return
		end
		if not connection.Connected then
			return
		end

		-- Clean up any previous callback for this attribute
		local previousCleanup = cleanupPerAttribute[attributeName]
		if typeof(previousCleanup) == "function" then
			task.spawn(previousCleanup)
			cleanupPerAttribute[attributeName] = nil
		end

		if changeIds[attributeName] == nil then
			changeIds[attributeName] = 0
		end
		changeIds[attributeName] += 1
		local id = changeIds[attributeName]

		local newValue = instance:GetAttribute(attributeName)
		if newValue == nil then
			return
		end
		if not attributeGuard(attributeName, newValue) then
			return
		end

		-- Run the callback in protected mode
		local success, cleanupOrTrace = xpcall(function(attributeName, value)
			local clean = callback(attributeName, value)
			if clean ~= nil then
				assert(typeof(clean) == "function", "callback must return a function or nil")
			end
			return clean
		end, debug.traceback, attributeName :: any, newValue :: any)

		if not success then
			local errMessage = ""
			local firstLine = string.split(cleanupOrTrace :: any, "\n")[1]
			local lastColon = string.find(firstLine, ": ")
			if lastColon then
				errMessage = firstLine:sub(lastColon + 1)
			end
			warn(`error while calling observeAttributes({instance}) callback:{errMessage}\n{cleanupOrTrace}`)
			return
		end

		local cleanup = cleanupOrTrace :: (() -> ())?
		if cleanup then
			-- Keep only if the value has not changed again and the connection is still alive
			local stillCurrent = changeIds[attributeName] == id
			local stillConnected = connections[attributeName] ~= nil and connections[attributeName].Connected

			if stillCurrent and stillConnected then
				cleanupPerAttribute[attributeName] = cleanup
			else
				task.spawn(cleanup)
			end
		end
	end

	-- Connect per-attribute signals
	for name, _ in namesSet do
		local conn = instance:GetAttributeChangedSignal(name):Connect(function()
			onAttributeChanged(name)
		end)
		connections[name] = conn
	end

	-- Seed with existing values for listed attributes
	for name, _ in namesSet do
		task.defer(onAttributeChanged, name)
	end

	-- Return a stopper that disconnects and cleans up everything
	return function()
		for name, conn in pairs(connections) do
			if conn.Connected then
				conn:Disconnect()
			end
			connections[name] = nil
		end

		for name, cleanup in pairs(cleanupPerAttribute) do
			cleanupPerAttribute[name] = nil
			if typeof(cleanup) == "function" then
				task.spawn(cleanup)
			end
		end
	end
end

return observeAttributes