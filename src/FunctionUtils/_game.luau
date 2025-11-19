--!nonstrict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local _Signal = require(ReplicatedStorage.ModulesUniversal.Utilities.ModuleUtils._Signal)
local _Future = require("../ModuleUtils/_Future")
local Players = game:GetService("Players")
local _table = require(ReplicatedStorage.ModulesUniversal.Utilities.FunctionUtils._table)

local sfxSoundGroup: SoundGroup? do
	local master = SoundService:FindFirstChild("Master")
	if master then
		sfxSoundGroup = master:FindFirstChild("SFX")
	end
end

local Module = {}
local rng = Random.new(tick())

-----------------------------
-- UTIL FUNCTIONS --
-----------------------------

--[[
	Updates <code>GuiService.TouchControlsEnabled</code>.
]]
function Module.setTouchControlsEnabled(enabled)
	GuiService.TouchControlsEnabled = enabled
end

--[[
	Hides the client's chat window but doesn't disable it.
]]
function Module.hideChat()
	assert(RunService:IsClient(), "hideChat() is client-only!")
	pcall(function()
		StarterGui:SetCore("ChatActive", false)
	end)
end

--[[
	Shows the chat window if hidden.
]]
function Module.showChat()
	assert(RunService:IsClient(), "showChat() is client-only!")
	pcall(function()
		StarterGui:SetCore("ChatActive", true)
	end)
end

function Module.onPersistentLoaded(): _Future.Future<>
	return _Future.new(function()
		if not Module.isPersistentLoaded() then
			workspace.PersistentLoaded:Wait()
		end
	end)
end

--[[
	Checks if the PersistentLoaded event has fired by looking for <code>IsPersistentLoaded</code> attribute on <code>workspace</code>.
	Ensure you have a local script that sets this attribute!
]]
function Module.isPersistentLoaded(): boolean
	return workspace:GetAttribute("IsPersistentLoaded") == true
end

type RetryOptions = {
	MaxAttempts: number?,
	BaseDelay: number?,
	MaxDelay: number?,
}
--[[
	Repeatedly attempts to call <code>callback</code> with an exponential backoff with error handling.
	The callback is considered successfully executed if it encounters zero errors.
	Default max attempts is 5. Default delay is 1 second.
]]
function Module.retry<T, R>(callback: (...T) -> (R?), options: RetryOptions?, ...: T): _Future.Future<boolean, R?>
	return _Future.new(function(callback, options, ...)
		local maxAttempts = if options then options.MaxAttempts or 5 else 5
		local baseDelay = if options then options.BaseDelay or 1 else 1
		local maxDelay = if options then options.MaxDelay else nil

		for attempt = 1, maxAttempts do
			local success, result = _Future.try(callback, ...):Await()
			if success then
				return true, result
			end

			if attempt >= maxAttempts then
				break
			end

			local delay = baseDelay * 2 ^ (attempt - 1)
			if maxDelay then
				delay = math.min(delay, maxDelay)
			end

			task.wait(delay)
		end
		return false, nil
	end, callback, options, ...)
end

-- Allows you to call a lambda function to avoid creating closures.
function Module.call<T1..., T2...>(fn: (T1...) -> (T2...), ...: T1...): T2...
	return fn(...)
end

-- Attempts to grab given secret for this game.
function Module.getSecret(secretName: string): Secret?
	local success, result = pcall(HttpService.GetSecret, HttpService, secretName)
	if success then
		return result
	end
	return nil
end

do
	local shownPrompts = {}
	
	if RunService:IsClient() then
		ProximityPromptService.PromptShown:Connect(function(prompt)
			table.insert(shownPrompts, prompt)
		end)

		ProximityPromptService.PromptHidden:Connect(function(prompt)
			local index = table.find(shownPrompts, prompt)
			if index then
				table.remove(shownPrompts, index)
			end
		end)
	end
	
	--[[
		Returns all currently shown prompts on the client.
		This is not be immediately up-to-date due to deferred signaling.
	]]
	function Module.getShownPrompts(): { ProximityPrompt }
		assert(RunService:IsClient(), "getShownPrompts() is client-only!")
		return shownPrompts
	end
	
	--[[
		Returns if the prompt is currently shown for the client.
		This is not be immediately up-to-date due to deferred signaling.
	]]
	function Module.isPromptShown(prompt: ProximityPrompt)
		assert(RunService:IsClient(), "isPromptShown() is client-only!")
		return table.find(shownPrompts, prompt) ~= nil
	end
	
	--[[
		Observes when the given prompt becomes shown.
		Returns a cleanup function to stop the observer.
	]]
	function Module.observePromptShown(
		prompt: ProximityPrompt,
		callback: (prompt: ProximityPrompt) -> ( () -> () )?,
		guard: ( (prompt: ProximityPrompt) -> (boolean) )?
	): () -> ()
		local shownConnection: RBXScriptConnection
		local hiddenConnection: RBXScriptConnection
		local storedCleanup: ( () -> () )?
		
		local function onShown()
			if storedCleanup then
				task.spawn(storedCleanup)
			end
			
			if guard and not guard(prompt) then
				return
			end
			
			-- Run the callback in protected mode:
			local success, cleanup = xpcall(function(prompt)
				local clean = callback(prompt)
				if clean ~= nil then
					assert(typeof(clean) == "function", "callback must return a function or nil")
				end
				return clean
			end, debug.traceback, prompt)

			-- If callback errored, print out the traceback:
			if not success then
				local err = ""
				local firstLine = string.split(cleanup :: any, "\n")[1]
				local lastColon = string.find(firstLine, ": ")
				if lastColon then
					err = firstLine:sub(lastColon + 1)
				end
				warn(`error while calling observePromptShown() callback:{err}\n{cleanup}`)
				return
			end

			if cleanup then
				-- only keep the cleanup if we're still observing
				if shownConnection.Connected then
					storedCleanup = cleanup
				else
					-- otherwise run it immediately
					task.spawn(cleanup)
				end
			end
		end
		
		local function onHidden()
			if storedCleanup then
				task.spawn(storedCleanup)
				storedCleanup = nil
			end
		end
		
		shownConnection = prompt.PromptShown:Connect(onShown)
		hiddenConnection = prompt.PromptHidden:Connect(onHidden)
		
		if Module.isPromptShown(prompt) then
			task.defer(function()
				if not shownConnection.Connected then
					return
				end
			end)
		end
		
		return function()
			shownConnection:Disconnect()
			hiddenConnection:Disconnect()
			onHidden()
		end
	end
end

--[[
	Sets all prompts being enabled in-game via <code>ProximityPromptService</code>.
]]
function Module.setPromptsEnabled(enable: boolean)
	assert(typeof(enable) == "boolean", "expected boolean")
	ProximityPromptService.Enabled = enable
end

-- Reduces memory usage for RBXScriptSignal handlers by only capturing a single upvalue.
-- Upvalue memory usage is <code>32 + 28n</code> bytes where <code>n</code> is the number of upvalues.
function Module.connect(signal: RBXScriptSignal, fn, ...)
	assert(typeof(signal) == "RBXScriptSignal", "invalid signal given to connect")
	local args = table.pack(fn, ...)

	return signal:Connect(function(...)
		-- Fast path: no bound args
		local fn = args[1]
		if args.n == 1 then
			return fn(...)
		end
		local signalArgCount = select("#", ...)
		-- Fast path: no signal args
		if signalArgCount == 0 then
			return fn(table.unpack(args, 2, args.n))
		end

		-- General case: combine signal args + bound args
		local totalCount = signalArgCount + args.n
		local totalArgs = table.create(totalCount)

		for i = 1, signalArgCount do
			totalArgs[i] = select(i, ...)
		end

		for i = 2, args.n do
			local boundIndex = i - 1
			totalArgs[signalArgCount + boundIndex] = args[i]
		end

		return fn(table.unpack(totalArgs, 1, totalCount))
	end)
end

do
	local globalThrottleState: { [any]: boolean } = {}
	--[[
		Runs <strong>func</strong> immediately and blocks all further calls until the deferred delay is over.
	]]
	function Module.throttleDeferGlobal<T...>(
		func: (T...) -> (),
		...: T...
	): boolean
		if globalThrottleState[func] then
			return false
		end

		globalThrottleState[func] = true
		task.defer(function()
			globalThrottleState[func] = nil
		end)

		task.spawn(func, ...)
		return true
	end
	
	local throttleState: { [any]: { [any]: boolean } } = {}
	-- Runs <strong>func</strong> immediately and blocks further calls until the deferred delay is over.
	-- <strong>identifier</strong> is stored per function and is not global.
	function Module.throttleDefer<T, A...>(
		identifier: T,
		func: (T, A...) -> (),
		...: A...
	): boolean
		throttleState[func] = throttleState[func] or {}

		if throttleState[func][identifier] then
			return false
		end

		throttleState[func][identifier] = true
		task.defer(function()
			throttleState[func][identifier] = nil
			if not next(throttleState[func]) then
				throttleState[func] = nil
			end
		end)

		task.spawn(func, identifier, ...)
		return true
	end
	
	local heartbeatThrottleGlobal: { [any]: boolean } = {}
	--[[
		Runs <strong>func</strong> immediately and blocks all further calls until next heartbeat.
	]]
	function Module.throttleHeartbeatGlobal<T...>(
		func: (T...) -> (),
		...: T...
	): boolean
		-- if already throttled, bail out
		if heartbeatThrottleGlobal[func] then
			return false
		end
		heartbeatThrottleGlobal[func] = true

		RunService.Heartbeat:Once(function()
			heartbeatThrottleGlobal[func] = nil
		end)

		task.spawn(func, ...)

		return true
	end
	
	local heartbeatThrottleState: { [any]: { [any]: boolean } } = {}
	-- Runs <strong>func</strong> immediately and blocks further calls until next heartbeat.
	-- <strong>identifier</strong> is stored per function and is not global.
	function Module.throttleHeartbeat<T, A...>(
		identifier: T,
		func: (T, A...) -> (),
		...: A...
	): boolean
		heartbeatThrottleState[func] = heartbeatThrottleState[func] or {}

		-- if already throttled, bail out
		if heartbeatThrottleState[func][identifier] then
			return false
		end
		heartbeatThrottleState[func][identifier] = true

		RunService.Heartbeat:Once(function()
			heartbeatThrottleState[func][identifier] = nil
			if not next(heartbeatThrottleState[func]) then
				heartbeatThrottleState[func] = nil
			end
		end)

		task.spawn(func, identifier, ...)

		return true
	end

	local timeThrottleGlobal: { [any]: number } = {}
	--[[
		Runs <strong>func</strong> immediately and blocks all further calls until the time delay is over.
	]]
	function Module.throttleGlobal<T...>(
		delay: number,
		func: (T...) -> (),
		...: T...
	): boolean
		local now = os.clock()
		local last = timeThrottleGlobal[func]
		if last and now - last < delay then
			return false
		end

		timeThrottleGlobal[func] = now
		task.spawn(func, ...)

		task.delay(delay, function()
			-- to avoid memory leaks
			timeThrottleGlobal[func] = nil
		end)

		return true
	end

	local timeThrottle: { [any]: { [any]: number } } = {}
	-- Runs <strong>func</strong> immediately and blocks further calls until the time delay is over.
	-- <strong>identifier</strong> is stored per function and is not global.
	function Module.throttle<T, A...>(
		identifier: T,
		delay: number,
		func: (T, A...) -> (),
		...: A...
	): boolean
		timeThrottle[func] = timeThrottle[func] or {}
		local now = os.clock()
		local last = timeThrottle[func][identifier]
		if last and now - last < delay then
			return false
		end

		timeThrottle[func][identifier] = now
		task.spawn(func, identifier, ...)

		task.delay(delay, function()
			-- to avoid memory leaks
			if not timeThrottle[func] then
				return
			end
			if timeThrottle[func][identifier] == now then
				timeThrottle[func][identifier] = nil
			end
			if not next(timeThrottle[func]) then
				timeThrottle[func] = nil
			end
		end)

		return true
	end
end

function Module.cloneTweenInfo(tweenInfo: TweenInfo, overrides: { [any]: any }?): TweenInfo
	local time = if overrides then overrides.Time or tweenInfo.Time else tweenInfo.Time
	local easingStyle = if overrides then overrides.EasingStyle or tweenInfo.EasingStyle else tweenInfo.EasingStyle
	local easingDirection = if overrides then overrides.EasingDirection or tweenInfo.EasingDirection else tweenInfo.EasingDirection
	local repeatCount = if overrides then overrides.RepeatCount or tweenInfo.RepeatCount else tweenInfo.RepeatCount
	local reverses = if overrides then overrides.Reverses or tweenInfo.Reverses else tweenInfo.Reverses
	local delayTime = if overrides then overrides.DelayTime or tweenInfo.DelayTime else tweenInfo.DelayTime

	return TweenInfo.new(time, easingStyle, easingDirection, repeatCount, reverses, delayTime)
end

function Module.inFirstPerson(distanceDelta: number?): boolean
	assert(RunService:IsClient(), "inFirstPerson() can only be called by client.")
	local dist = (workspace.CurrentCamera.CFrame.Position - workspace.CurrentCamera.Focus.Position).Magnitude

	local distanceDelta = distanceDelta or 0
	local threshold = math.max(0, 0.501 + distanceDelta)

	return dist <= threshold
end

-- DEPRECATED --
do
	local SPEED_OF_SOUND = 343 -- meters per second
	local METERS_PER_STUD = 0.28 -- 1 stud is approx 0.28 meter

	-- <strong><code>!DEPRECATED!</code></strong>
	-- <strong><code>!YIELDS!</code></strong>
	-- Use <code>Math.getSoundTravelDuration()</code> instead
	-- This will yield for the exact duration it takes for sound to travel the given distance.
	function Module.yieldForSoundTravel(distanceInStuds: number)
		warn("yieldForSoundTravel() is deprecated")
		local distanceInMeters = distanceInStuds * METERS_PER_STUD
		local timeToYield = distanceInMeters / SPEED_OF_SOUND

		task.wait(timeToYield)
	end
end
-- --

-- <strong><code>!YIELDS!</code></strong>
-- Pauses the current thread until the end of the current resumption cycle.
function Module.defer()
	local current = coroutine.running()
	task.defer(function()
		if coroutine.status(current) == "suspended" then
			task.spawn(current)
		end
	end)
	return coroutine.yield()
end

--[[
	Yields until the instance property obtains a value.
	This is great for ensuring there are instances on properties like:
	- PrimaryPart
	- Part0/Part1
	- Attachment0/Attachment1
]]
@[deprecated {use="Object.waitForProperty()"}]
function Module.waitForInstanceProperty(property: string, instance: Instance, timeout: number?): any
	local success, value = pcall(function()
		return instance[property]
	end)
	if not success then
		error(`invalid property: {property} for instance: {instance.ClassName}`, 2)
	end
	if value then
		return value
	end
	
	local thread = coroutine.running()
	local connection
	connection = instance:GetPropertyChangedSignal(property):Connect(function()
		local value = instance[property]
		if not value then
			return
		end
		if not connection then
			return
		end
		connection = nil
		
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, value)
		end
	end)
	
	if timeout then
		task.delay(timeout, function()
			if not connection then
				return
			end
			connection:Disconnect()
			connection = nil
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread)
			end
		end)
	end
	
	return coroutine.yield()
end

-- This function will yield until all supplied signals fire once with a timeout.
-- -1 for no timeout
-- <strong><code>!YIELDS!</code></strong>
function Module.waitForAll<Func, T...>(timeoutInSeconds: number, ...: RBXScriptSignal | _Signal.SignalType<Func, T...>): (boolean, T...)
	local events = table.pack(...)
	local connections = {} :: { any }
	local totalCount = #events
	local count = 0
	local thread = coroutine.running()

	local function onEvent()
		if not connections then
			return
		end

		count += 1
		if count >= totalCount then
			connections = nil
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread, true)
			end
		end
	end

	for i, event: RBXScriptSignal in ipairs(events) do
		connections[i] = event:Once(onEvent)
	end

	if timeoutInSeconds >= 0 then
		task.delay(timeoutInSeconds, function()
			if not connections then
				return
			end

			for _, connection in connections do
				connection:Disconnect()
			end
			connections = nil
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread, true)
			end
		end)
	end

	return coroutine.yield()
end

-- <strong><code>!YIELDS!</code></strong>
function Module.waitForEither<Func, T...>(eventYes: RBXScriptSignal | _Signal.SignalType<Func, T...>, eventNo: RBXScriptSignal | _Signal.SignalType<Func, T...>): boolean
	local eventYes = eventYes -- fixes type annotation issue
	local eventNo = eventNo -- fixes type annotation issue
	local thread = coroutine.running()

	local connection1 = nil
	local connection2 = nil
	
	connection1 = eventYes:Once(function(...)
		if connection1 == nil then
			return
		end

		connection1:Disconnect()
		connection2:Disconnect()
		connection1 = nil
		connection2 = nil

		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, true, ...)
		end
	end)

	connection2 = eventNo:Once(function(...)
		if connection2 == nil then
			return
		end

		connection1:Disconnect()
		connection2:Disconnect()
		connection1 = nil
		connection2 = nil
		
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, false, ...)
		end
	end)

	return coroutine.yield()
end

-- -1 for no timeout
-- <strong><code>!YIELDS!</code></strong>
function Module.waitForAny(timeoutInSeconds: number, ...: RBXScriptSignal | _Signal.SignalType<any, ...any>): (boolean, ...any)
	local thread = coroutine.running()
	local connections = {} :: { any }

	local function disconnectAll()
		for _, connection in connections do
			connection:Disconnect()
		end

		connections = nil
	end

	local function onEvent(...)
		if not connections then
			return
		end

		disconnectAll()
		
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, false, ...)
		end
	end

	for _, event in {...} do
		table.insert(connections, event:Once(onEvent))
	end

	if timeoutInSeconds >= 0 then
		task.delay(timeoutInSeconds, function()
			if not connections then
				return
			end

			disconnectAll()
			
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread, true)
			end
		end)
	end

	return coroutine.yield()
end

-- <strong><code>!YIELDS!</code></strong>
function Module.waitWithTimeout<Func, T...>(event: RBXScriptSignal | _Signal.SignalType<Func, T...>, timeoutInSeconds: number): (boolean, T...)
	local event = event
	local thread = coroutine.running()
	local connection

	local function onOnce(...)
		if not connection then
			return
		end

		connection:Disconnect()
		connection = nil
		
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, false, ...)
		end
	end

	connection = event:Once(onOnce)

	task.delay(timeoutInSeconds, function()
		if not connection then
			return
		end

		connection:Disconnect()
		connection = nil

		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, true)
		end
	end)

	return coroutine.yield()
end

do
	type RaycastResultData = {
		Instance: Instance,
		Position: Vector3,
		Normal: Vector3,
		Material: Enum.Material,
		Distance: number
	}

	function Module.createRemoteCompatibleRaycastResult(result: RaycastResult): RaycastResultData
		return {
			Instance = result.Instance,
			Position = result.Position,
			Normal = result.Normal,
			Material = result.Material,
			Distance = result.Distance
		} :: RaycastResultData
	end

	-- Client-only!
	function Module.getMouseRay(params: RaycastParams, maxDistance: number?): Ray
		assert(RunService:IsClient(), "getMouseRay can only be used from client-side!")
		local mousePos = UserInputService:GetMouseLocation()
		maxDistance = maxDistance or 5000
		return workspace.CurrentCamera:ViewportPointToRay(mousePos.X, mousePos.Y)
	end
	
	-- Client-only!
	function Module.raycastFromMouse(params: RaycastParams, maxDistance: number?): (RaycastResult?, Ray)
		assert(RunService:IsClient(), "raycastFromMouse can only be used from client-side!")
		local mousePos = UserInputService:GetMouseLocation()
		maxDistance = maxDistance or 5000
		local mouseRay = workspace.CurrentCamera:ViewportPointToRay(mousePos.X, mousePos.Y)

		local direction = mouseRay.Direction * maxDistance
		local result = workspace:Raycast(mouseRay.Origin, direction, params)

		return result, Ray.new(mouseRay.Origin, direction)
	end
	
	-- Client-only!
	function Module.raycastFromScreenCenter(params: RaycastParams, maxDistance: number?): (RaycastResult?, Ray)
		assert(RunService:IsClient(), "raycastFromScreenCenter can only be used from client-side!")
		maxDistance = maxDistance or 5000
		local mouseRay = workspace.CurrentCamera:ViewportPointToRay(
			workspace.CurrentCamera.ViewportSize.X/2,
			workspace.CurrentCamera.ViewportSize.Y/2
		)

		local direction = mouseRay.Direction * maxDistance
		local result = workspace:Raycast(mouseRay.Origin, direction, params)

		return result, Ray.new(mouseRay.Origin, direction)
	end
	
	-- Client-only!
	-- Shorthand for <code>UserSettings():GetService("UserGameSettings") :: UserGameSettings</code>
	-- Returns the class that stores all client-side settings, such as graphics quality level.
	function Module.getUserSettings(): UserGameSettings
		return UserSettings():GetService("UserGameSettings")
	end
end

function Module.getPlayerList(exclude: { Player }?): {Player}
	if not exclude then
		return Players:GetPlayers()
	end
	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if exclude and table.find(exclude, player) then
			continue
		end
		table.insert(result, player)
	end
	return result
end

-- Currently, :GetPlayerFromCharacter is not safe to call in parallel (which makes no sense).
function Module.getPlayerFromCharacterWriteSafe(character: Model): Player?
	for _, player in Players:GetPlayers() do
		if player.Character == character then
			return player
		end
	end
	return
end

-- DEPRECATED!
-- Use <code>Remotes.fireToAllClientsExcept()</code>
function Module.fireToAllClientsExcept(exception: { Player }, remote: RemoteEvent, ...: any)
	warn("Game.fireToAllClientsExcept() is deprecated")
	local players = Module.getPlayerList(exception)
	for _, player in players do
		remote:FireClient(player, ...)
	end
end

function Module.hasEnumKey(key: string, enumTable: { [any]: any }): boolean
	for _, thing in enumTable do
		if typeof(thing) == "table" then
			local found = Module.hasEnumKey(key, thing)
			if found then
				return found
			end
		elseif thing == key then
			return true
		end
	end

	return false
end

function Module.repeatUntil(repeatCallback: () -> boolean, condition: () -> boolean, yield: boolean)
	assert(repeatCallback ~= nil, "repeatCallback is invalid or nil")

	if yield then
		task.spawn(function()
			repeat repeatCallback() until (condition() == true)
		end)
	else
		repeat repeatCallback() until (condition() == true)
	end
end

-- Caches results from a pure function in a weak table so the same input
-- doesn't need to be calculated again for the same output.
function Module.memoize<T, U>(fn: (T) -> (U)): (T) -> (U)
	local cache = {}
	setmetatable(cache, {__mode = "kv"})
	return function(input: T)
		local result = cache[input]
		if not result[input] then
			result = fn(input)
			cache[input] = result
			return result
		end
		return result
	end
end

-- Returns the game's PlaceVersion
function Module.getBuild(): "STUDIO" | string
	if RunService:IsStudio() then
		return "STUDIO"
	else
		return ("%d"):format(game.PlaceVersion)
	end
end

do
	local PRIVATE_ID_ATTRIBUTE = "__PrivateServerId"
	local PRIVATE_OWNER_ATTRIBUTE = "__PrivateServerOwnerId"

	if RunService:IsServer() then
		ReplicatedStorage:SetAttribute(PRIVATE_ID_ATTRIBUTE, game.PrivateServerId)
		ReplicatedStorage:SetAttribute(PRIVATE_OWNER_ATTRIBUTE, game.PrivateServerOwnerId)
	else
		if
			not ReplicatedStorage:GetAttribute(PRIVATE_OWNER_ATTRIBUTE)
			or not ReplicatedStorage:GetAttribute(PRIVATE_ID_ATTRIBUTE)
		then
			warn(`failed to get ServerId information on client-side - did you forget to require FunctionUtils on the server-side?`)
		end
	end

	--[[
		Gets a string label for the current server type.
		This can be accurately checked by client & server despite <code>game.PrivateServerId</code> and <code>game.PrivateServerOwnerId</code> being non-replicated.
	]]
	function Module.getServerType(): "PRIVATE" | "RESERVED" | "STANDARD"
		local privateServerId = ReplicatedStorage:GetAttribute(PRIVATE_ID_ATTRIBUTE) or game.PrivateServerId
		local privateServerOwnerId =  ReplicatedStorage:GetAttribute(PRIVATE_OWNER_ATTRIBUTE) or game.PrivateServerOwnerId

		if privateServerId ~= "" then
			if privateServerOwnerId ~= 0 then
				return "PRIVATE"
			else
				return "RESERVED"
			end
		else
			return "STANDARD"
		end
	end

	--[[
		Indicates if this is a server that was purchased by a player.
		This can be accurately checked by client & server despite <code>game.PrivateServerId</code> and <code>game.PrivateServerOwnerId</code> being non-replicated.
	]]
	function Module.isPrivateServer(): boolean
		local privateServerId = ReplicatedStorage:GetAttribute(PRIVATE_ID_ATTRIBUTE) or game.PrivateServerId
		local privateServerOwnerId =  ReplicatedStorage:GetAttribute(PRIVATE_OWNER_ATTRIBUTE) or game.PrivateServerOwnerId

		return privateServerId ~= "" and privateServerOwnerId ~= 0
	end

	--[[

		Indicates if this is a reserved server created through the TeleportService.
		This can be accurately checked by client & server despite <code>game.PrivateServerId</code> and <code>game.PrivateServerOwnerId</code> being non-replicated.
	]]
	function Module.isReservedServer(): boolean
		local privateServerId = ReplicatedStorage:GetAttribute(PRIVATE_ID_ATTRIBUTE) or game.PrivateServerId
		local privateServerOwnerId =  ReplicatedStorage:GetAttribute(PRIVATE_OWNER_ATTRIBUTE) or game.PrivateServerOwnerId

		return privateServerId ~= "" and privateServerOwnerId == 0
	end

	--[[
		DEPRECATED
		Use: <code>isPrivateServer()</code>
	]]
	@deprecated
	function Module.isVIPServer(): boolean
		warn("isVIPServer() is deprecated")
		return game.PrivateServerId ~= "" and game.PrivateServerOwnerId ~= 0
	end
end

--[[
	Gets the game build with a server type specified for debugging.
	This can be called from client and server.
]]
function Module.getBuildWithServerType(): string
	return Module.getBuild() .. "-" .. Module.getServerType()
end

type ExtraCreateParams = {
	OnCreating: typeof(
		-- Called right before the instance is parented.
		function(instance: any)
			
		end
	)?,
	Seed: number?,
	IntegerRandomizedProperties: { string }? -- any number range values will use NextInteger() instead of NextNumber()
}
--[[
	Alternative to <code>Instance.new()</code> that allows you to apply properties at the same time.
	If the <code>Parent</code> property is included, it will be applied last.
	Any properties that are supposed to be numbers but are provided as NumberRange will be randomized via <code>:NextNumber()</code>.
	Any values that are tables are presumed to be new instances that will be made children of the primary instance.
	<strong>extraParams</code>: Extra configuring options. This is passed down to child instances.
]]
function Module.create(className, properties: { [any]: any }?, extraParams: ExtraCreateParams?)
	local extraParams: ExtraCreateParams = extraParams or {}
	local integerRandomizedProperties = extraParams.IntegerRandomizedProperties or {}
	local instance = Instance.new(className)
	local rng = if extraParams.Seed then Random.new(extraParams.Seed) else rng
	
	local parent
	if properties then
		for name, value in pairs(properties) do
			if name == "Parent" then
				parent = value
				continue
			elseif typeof(value) == "table" then
				local newInstance = Module.create(name, value, extraParams)
				newInstance.Parent = instance
				continue
			elseif
				typeof(value) == "NumberRange"
				and typeof(instance[name]) == "number"
			then
				value = if table.find(integerRandomizedProperties, name) then rng:NextInteger(value.Min, value.Max) else rng:NextNumber(value.Min, value.Max)
			end
			local success, err = pcall(function()
				instance[name] = value
			end)
			if not success then
				warn(err)
			end
		end
	end
	
	if extraParams.OnCreating then
		extraParams.OnCreating(instance)
	end
	
	instance.Parent = parent
	
	return instance
end

-- Creates the sound. Automatically parents to SoundService if no parent is provided.
-- Sound has parent set last. Default SoundGroup is SFX (if present)
function Module.createSound(properties: { [string]: any }): Sound
	local sound = Instance.new("Sound")
	local parent, soundGroup = SoundService, sfxSoundGroup
	for property, value in pairs(properties) do
		if property == "Parent" then
			parent = value
			continue
		end
		if property == "SoundGroup" then
			soundGroup = value
			continue
		end
		sound[property] = value
	end
	sound.Parent = parent
	sound.SoundGroup = soundGroup
	return sound
end

-- Automatically cleans up the sound once it ends.
-- Default parent is SoundService.
function Module.playSoundClone(sound: Sound, parent: Instance?): Sound
	local clone = sound:Clone()
	clone.Parent = parent or SoundService
	clone.Ended:Once(function()
		clone:Destroy()
	end)
	clone:Play()
	return clone
end

-- Automatically cleans up the sound once it ends. Parent property will be ignored.
-- Default SoundGroup is SFX (if present)
function Module.playSoundFollow(soundProperties: { [string]: any }, follow: BasePart | Attachment): Sound
	local sound = Instance.new("Sound")
	local soundGroup = sfxSoundGroup
	for name, value in pairs(soundProperties) do
		if name == "SoundGroup" then
			soundGroup = value
			continue
		end
		sound[name] = value
	end
	sound.SoundGroup = soundGroup
	
	local myFollowPart = Instance.new("Part")
	myFollowPart.Transparency = 1
	myFollowPart.Anchored = true
	myFollowPart.CanCollide = false
	myFollowPart.CanQuery = false
	myFollowPart.CanTouch = false
	myFollowPart.Size = if follow:IsA("BasePart") then follow.Size else Vector3.new(1, 1, 1)
	
	sound.Parent = myFollowPart
	myFollowPart.Parent = workspace
	local connection = RunService.RenderStepped:Connect(function()
		myFollowPart.Position = if follow:IsA("Attachment") then follow.WorldPosition else follow.Position
	end)
	sound:Play()
	sound.Ended:Once(function()
		connection:Disconnect()
		myFollowPart:Destroy()
	end)
	
	return sound
end

-- Automatically cleans up the sound once it ends.
-- Default SoundGroup is SFX (if present)
function Module.playSoundInWorld(soundProperties: { [string]: any }, position: Vector3): Sound
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	local sound = Instance.new("Sound")
	local soundGroup = sfxSoundGroup
	for name, value in pairs(soundProperties) do
		if name == "SoundGroup" then
			soundGroup = value
			continue
		end
		sound[name] = value
	end
	sound.SoundGroup = soundGroup
	sound.Parent = attachment
	attachment.Parent = workspace.Terrain
	sound:Play()
	sound.Ended:Once(function()
		attachment:Destroy()
	end)
	return sound
end

-- Plays the song for you and automatically cleans it up.
function Module.playSoundOnce(sound: Sound)
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
end

do
	type SoundEntry = {
		Sound: Sound,
		CleanupToken: number, -- increments to invalidate any scheduled cleanup
		EndedConnection: RBXScriptConnection?
	}
	local soundCache: {
		[Instance]: {
			[string]: SoundEntry
		}
	} = {}

	--[[
		Automatically cleans up the sound once it ends + 10 second delay.
		If the same sound (matching SoundId) is played again within the same instance, the sound will be reused and the timer will be reset.
		This is useful to avoid client constantly re-downloading frequently used sounds.
	]]
	function Module.playSoundCached(soundProperties: { [string]: any }, parent: Instance?): Sound
		local resolvedParent = parent or SoundService
		local resolvedSoundGroup = sfxSoundGroup

		-- We need SoundId to look up the cache. Also collect other props to (re)apply.
		local pendingProps: { [string]: any } = {}
		local requestedSoundId: string? = nil
		local usePlayOnRemove: boolean = false

		for propertyName, propertyValue in pairs(soundProperties) do
			if propertyName == "Parent" then
				resolvedParent = propertyValue
			elseif propertyName == "SoundGroup" then
				resolvedSoundGroup = propertyValue
			elseif propertyName == "SoundId" then
				requestedSoundId = propertyValue
				pendingProps[propertyName] = propertyValue
			elseif propertyName == "PlayOnRemove" then
				usePlayOnRemove = propertyValue == true
			else
				pendingProps[propertyName] = propertyValue
			end
		end

		-- If they did not provide a SoundId, we cannot cache reliably.
		-- Fall back to one-shot creation with the same lifecycle guarantees.
		if requestedSoundId == nil then
			local freshSound = Instance.new("Sound")
			freshSound.SoundGroup = resolvedSoundGroup
			freshSound.Parent = resolvedParent

			for propertyName, propertyValue in pairs(pendingProps) do
				freshSound[propertyName] = propertyValue
			end

			if usePlayOnRemove then
				-- Play-on-remove is inherently one-shot and not cacheable.
				freshSound:Destroy()
				return freshSound
			end

			freshSound:Play()

			freshSound.Ended:Once(function()
				-- Delay cleanup by 10 seconds after the sound ends.
				task.delay(10, function()
					if freshSound.Parent ~= nil then
						freshSound:Destroy()
					end
				end)
			end)

			return freshSound
		end

		-- Ensure there is a bucket for this parent.
		if not soundCache[resolvedParent] then
			soundCache[resolvedParent] = {}
		end

		local parentBucket = soundCache[resolvedParent]
		local entry: SoundEntry = parentBucket[requestedSoundId] :: any

		-- Create or reuse the sound
		if not entry or not entry.Sound.Parent then
			local newSound = Instance.new("Sound")
			newSound.SoundGroup = resolvedSoundGroup
			newSound.Parent = resolvedParent

			-- Apply all requested properties (including SoundId)
			for propertyName, propertyValue in pairs(pendingProps) do
				newSound[propertyName] = propertyValue
			end

			-- Initialize cache entry
			entry = {
				Sound = newSound,
				CleanupToken = 0,
				EndedConnection = nil,
			}
			parentBucket[requestedSoundId] = entry
			assert(entry, "stupid type annotation")
			
			-- Connect once; each Ended triggers a cleanup schedule tied to the current token.
			entry.EndedConnection = newSound.Ended:Connect(function()
				local tokenAtEnd = entry.CleanupToken
				task.delay(10, function()
					if tokenAtEnd ~= entry.CleanupToken then
						return
					end
					if newSound.Parent then
						-- Remove from cache first to avoid stale pointers.
						parentBucket[requestedSoundId] = nil
						newSound:Destroy()
					end
				end)
			end)
		else
			-- Reuse the cached sound. Make sure it lives under the latest parent and group.
			if entry.Sound.Parent ~= resolvedParent then
				entry.Sound.Parent = resolvedParent
			end
			if entry.Sound.SoundGroup ~= resolvedSoundGroup then
				entry.Sound.SoundGroup = resolvedSoundGroup
			end

			-- Update properties in case the caller changed anything (volume, speed, etc.)
			for propertyName, propertyValue in pairs(pendingProps) do
				entry.Sound[propertyName] = propertyValue
			end
		end

		local sound = entry.Sound

		if usePlayOnRemove then
			-- Caller explicitly wants PlayOnRemove semantics; do not keep cached.
			-- Destroying will play the sound immediately (one-shot), then we clear the cache entry.
			parentBucket[requestedSoundId] = nil
			if sound then
				if entry.EndedConnection then
					entry.EndedConnection:Disconnect()
					entry.EndedConnection = nil
				end
				sound:Destroy()
			end
			return sound
		end

		-- Start or restart playback & reset cleanup timer token
		entry.CleanupToken += 1
		sound:Play()

		return sound
	end
end

-- Automatically cleans up the sound once it ends.
-- Default parent is the SoundService, Default SoundGroup is SFX (if present)
function Module.playSound(soundProperties: { [string]: any }, parent: Instance?): Sound
	local sound = Instance.new("Sound")
	local parent, soundGroup = parent or SoundService, sfxSoundGroup
	for name, value in pairs(soundProperties) do
		if name == "Parent" then
			parent = value
			continue
		end
		if name == "SoundGroup" then
			soundGroup = value
			continue
		end
		sound[name] = value
	end
	sound.SoundGroup = soundGroup
	sound.Parent = parent
	if sound.PlayOnRemove then
		sound:Destroy()
	else
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	return sound
end

-- Automatically cleans up the sound once it ends.
-- Default SoundGroup is SFX (if present)
function Module.playRandomSound(soundIds: {string}, soundProperties: { [string]: any }, parent: Instance): Sound
	local soundId = soundIds[rng:NextInteger(1, #soundIds)]

	local sound = Instance.new("Sound")
	local soundGroup = sfxSoundGroup
	for name, value in pairs(soundProperties) do
		if name == "SoundGroup" then
			soundGroup = value
			continue
		end
		sound[name] = value
	end
	sound.SoundGroup = soundGroup
	sound.SoundId = soundId
	sound.Parent = parent
	if sound.PlayOnRemove then
		sound:Destroy()
	else
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	return sound
end

-- Automatically cleans up the sound once it ends.
function Module.playRandomSoundClone(sounds: { Sound }, source: Instance, destroyFirst: boolean?, volume: number?): Sound
	local soundTemplate = sounds[rng:NextInteger(1, #sounds)]

	local sound = soundTemplate:Clone()
	sound.Volume *= (volume or 1)
	
	sound.Parent = source
	if destroyFirst or sound.PlayOnRemove then
		sound.PlayOnRemove = true
		sound:Destroy()
	else
		sound:Play()
		sound.Ended:Once(function()
			sound:Destroy()
		end)
	end
	
	return sound
end

return Module
