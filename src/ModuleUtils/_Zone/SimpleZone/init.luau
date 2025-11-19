--!optimize 2
--!strict
--?module-ancestors {script, script.Utility}

--[[
	Zone Module (open source ver 2)
	
	Author: athar_adv
]]

local RunService 			= game:GetService('RunService')
local Players 				= game:GetService('Players')
local ServerStorage			= game:GetService('ServerStorage')
local ReplicatedStorage		= game:GetService('ReplicatedStorage')

local IS_CLIENT				= RunService:IsClient()

local utility				= script.Utility
local templates				= script.Templates

local Signal 				= require(utility.SimpleSignal)
local t						= require("@self/Utility/t")
local UtilityFunctions		= require(utility.UtilityFunctions)
local getBoundingBox		= require(utility.getBoundingBoxFromBoxes)

local SearchFor 			= require(script.SearchFor)
local Tracker				= require(script.Tracker)
local Zones					= require(script.Zones)

local characterObjects		= Tracker.characterObjects

local t_assert				= t.t_assert

local updateClassStorage	= UtilityFunctions.updateClassStorage
local copyToQuerySpace		= UtilityFunctions.copyToQuerySpace
local removeFromQuerySpace	= UtilityFunctions.removeFromQuerySpace
local T_TYPES				= UtilityFunctions.TTypes

local getBoxesFromParts		= UtilityFunctions.getBoxesFromParts

local workerTemplate		= IS_CLIENT and templates.ClientWorker or templates.ServerWorker

export type Metadata  = {[any]: any}
export type QueryOptions = {
	FireMode: "OnEnter"|"OnExit"|"Both"|"None",
	TrackItemEnabled: boolean,
	StoreByClass: boolean,
	AcceptMetadata: boolean,
	UpdateInterval: number,
	InSeperateQuerySpace: boolean,
	Static: boolean,
	QuerySpace: {
		Space: QuerySpace,
		World: WorldRoot
	}?
}

export type Box = {
	cframe: CFrame,
	size: Vector3
}
export type QuerySpace = {
	dynamic: {
		index: {BasePart},
		replicas: {BasePart}
	},

	static: {
		index: {BasePart},
		replicas: {BasePart}
	}
}
export type QueryInfo = {
	QueryParams: OverlapParams | (zone: Zone) -> OverlapParams, 
	QueryOptions: QueryOptions
}

local PART_WHITELIST = {
	Shape = true
}
local PART_BLACKLIST = {
	CFrame = true,
	Position = true,
	Orientation = true
}

-- A folder to store actors
local actorContainer	= Instance.new("Folder")
actorContainer.Name		= "SimpleZoneActors"
actorContainer.Parent 	= IS_CLIENT and Players.LocalPlayer.PlayerScripts or ServerStorage

-- A folder to store WorldModels
local worldContainer			= Instance.new("Folder")
worldContainer.Name		= `SimpleZoneQuerySpaces({IS_CLIENT and "Client" or "Server"})`
worldContainer.Parent	= IS_CLIENT and ReplicatedStorage or ServerStorage

local PartQueryJumpTable: {[string]: (_: WorldRoot, _: BasePart, _: OverlapParams?) -> {BasePart}} = {
	Block = function(worldModel, part, params)
		debug.profilebegin("INDEX_SIZE")
		local result = worldModel:GetPartBoundsInBox(part.CFrame, part.Size, params)
		debug.profileend()
		return result
	end,
	Ball = function(worldModel, part, params)
		return worldModel:GetPartBoundsInRadius(part.Position, part.ExtentsSize.Y, params)
	end
}

-- Create a new <code>QueryOptions</code> object.
local function queryop_new(): QueryOptions
	return {
		FireMode = "Both",
		TrackItemEnabled = false,
		StoreByClass = false,
		AcceptMetadata = false,
		UpdateInterval = 0,
		InSeperateQuerySpace = false,
		Static = true,
	}
end

local function assertQueryOp(queryOp: QueryOptions)
	t_assert("queryOp", queryOp, UtilityFunctions.QueryOptionsValidator, "QueryOptions")
end

local function getTracked(self: Zone, item): any
	for v in self.Tracked do
		if item:IsDescendantOf(v) then
			return v
		end
	end
	return nil
end

local function getItem(self: Zone, data: any): (any, Player?)
	local querySpace = self.QuerySpace
	local queryOptions = self.QueryOptions
	
	local item: any = (typeof(data) == "table" and queryOptions.AcceptMetadata) and data.item or data
	if querySpace ~= nil then
		local index = table.find(querySpace.dynamic.replicas, item)
		if index then
			item = querySpace.dynamic.index[index]
		end
	end
	
	return (queryOptions.TrackItemEnabled and getTracked(self, item)) or item, characterObjects[item]
end

local Zone = {}



--[[
	Updates the items of the <code>Zone</code> and fires events.
]]
function Zone.Update(self: Zone, params: OverlapParams?, onEnter: boolean?, onExit: boolean?): ()
	if type(self.Query) ~= "function" then
		self:UnbindFromHeartbeat()
		error(`Expected 'function' for Zone.Query, got '{typeof(self.Query)}'`)
	end
	
	local datas = self:Query(params)
	if typeof(datas) ~= "table" then
		self:UnbindFromHeartbeat()
		error(`Expected '\{any\}' for the ReturnType of Zone.Query, got '{typeof(datas)}'`)
	end
	
	local queryOptions = self.QueryOptions
	local storeByClass = queryOptions.StoreByClass
	local acceptMetadata = queryOptions.AcceptMetadata
	
	local lookup = {}
	local plrlookup = {}
	
	for _, data in datas do
		if lookup[data] then continue end
		local item, plr = getItem(self, data)
		-- As of version 157, the player and body parts are now seperated so they can be detected individually
		if plr and not plrlookup[plr] then
			plrlookup[plr] = true
			table.insert(datas, plr)
		end
		
		if lookup[item] then continue end
		lookup[item] = true

		if self.Items[item] then continue end
		
		local isTable = typeof(data) == "table"
		local metadata = isTable and data.metadata or true
		
		self.Items[item] = acceptMetadata and metadata or true
		
		if storeByClass then
			updateClassStorage(self, item, true)
		end
		if not onEnter then continue end
		
		self.ItemEntered:Fire(item, 
			if acceptMetadata and isTable then metadata else nil
		)
	end
	for item, metadata in self.Items do
		if lookup[item] then continue end
		local metadata = self.Items[item]
		self.Items[item] = nil
		
		if storeByClass then
			updateClassStorage(self, item, false)
		end
		if not onExit then continue end
		local isTable = type(metadata) == "table"
		
		self.ItemExited:Fire(item, 
			if acceptMetadata and isTable then metadata :: {[any]: any} else nil
		)
	end
end

--[[
	Stops the automatic query of the <code>Zone</code>.
]]
function Zone.UnbindFromHeartbeat(self: Zone): ()
	Zones.deregisterZone(self)
	table.clear(self.Items)
end

--[[
	(<strong>IMPORTANT</strong>)
	Starts the automatic query of the <code>Zone</code>.
	If <code>params</code> is provided, then all queries will be done using it.
	Otherwise, a function returning an <code>OverlapParams</code> to include all player characters will be used instead.
	Returns the <code>QueryInfo</code> which is used when querying the <code>Zone</code>.
]]
function Zone.BindToHeartbeat(self: Zone, params: (OverlapParams | (zone: Zone) -> OverlapParams)?): QueryInfo
	assert(params == nil or typeof(params) == "OverlapParams" or type(params) == "function", "params must be OverlapParams, function or nothing.")
	self:UnbindFromHeartbeat()
	
	local tbl = {
		QueryParams = params or UtilityFunctions.defaultParamGenerator,
		QueryOptions = self.QueryOptions
	} :: QueryInfo
	
	Zones.registerZone(self, tbl)
	
	return tbl
end

--[[
	If a descendant of <code>item</code> is found during query, <code>item</code> is returned instead of the descendant.
]]
function Zone.TrackItem(self: Zone, item: Instance): ()
	assert(typeof(item) == "Instance", `Bad item argument: {item} must be an instance.`)
	
	local trackItemEnabled = self.QueryOptions.TrackItemEnabled
	if not trackItemEnabled then
		warn("TrackItemEnabled is not enabled, cannot call Zone:TrackItem(...)")
		return
	end
	if self.Tracked[item] then
		warn(`Item {item} is already being tracked.`)
		return
	end
	self.Tracked[item] = true
	
	local connections = self.TrackerConnections
	connections[item] = item.Destroying:Once(function()
		connections[item] = nil
		self:UntrackItem(item)
	end)
end

--[[
	Untracks an item tracked by <code>Zone:TrackItem(...)</code>.
]]
function Zone.UntrackItem(self: Zone, item: Instance): ()
	assert(typeof(item) == "Instance", `Bad item argument: {item} must be an instance.`)
	
	if not self.Tracked[item] then
		warn(`Item {item} is not currently being tracked.`)
		return
	end
	self.Tracked[item] = nil
	
	local connections = self.TrackerConnections
	if connections[item] then
		connections[item]:Disconnect()
		connections[item] = nil
	end
end

--[[
	Gets all items contained within the zone which are of <code>class</code> class/type.
]]
function Zone.GetItemsWhichAreA(self: Zone, class: string): {any}
	assert(typeof(class) == "string", "Bad class argument: class must be a string.")
	
	if not self.QueryOptions.StoreByClass then
		warn("StoreByClass is not enabled, cannot call Zone:GetItemsWhichAreA(...)")
		return {}
	end
	
	return self.StoredClasses[class] or {}
end

--[[
	Queries the <code>Zone</code> for <code>Instance</code>s with the specified properties.
	
	If <code>mode</code> is <code>"And"</code>, then it will only return <code>Instance</code>s that fully match the properties.
	Else if <code>mode</code> is <code>"Or"</code>, then it will return <code>Instance</code>s that match atleast one of the properties.
]]
function Zone.SearchFor(self: Zone, properties: {{Name: string, Value: any, Type: ("Attribute" | "Tag")?}}, mode: "And" | "Or"): {BasePart}?
	t_assert("properties", properties, t.array(t.interface {
		Name = t.string,
		Value = t.optional(t.any),
		Type = t.optional(t.string)
	}) "{| {Name: string, Value: any, Type: 'Tag' | 'Attribute'} |}")
	t_assert("mode", mode, t.union(t.literal("And"), t.literal("Or")))
	assert(type(self.Query) == "function", `Expected 'function' for Zone.Query, got '{typeof(self.Query)}'`)
	
	local parts = self:Query()
	
	return SearchFor(
		parts,
		properties,
		mode
	)
end

type ListenerDatatype =  
	| string 
	| "LocalPlayer" 
	| "Player" 
	| "BasePart"
	| "BodyPart"

--[[
	Calls <code>fn</code> when an item of class <code>datatype</code> enters/exits the <code>Zone</code>.
]]
function Zone.ListenTo(self: Zone, datatype: ListenerDatatype, mode: "Entered"|"Exited", fn: (item: Instance, metadata: Metadata?) -> ()): RBXScriptConnection
	if datatype == "LocalPlayer" and not IS_CLIENT then
		error("Can only listen to LocalPlayer on the client.")
	end
	t_assert("datatype", datatype, "string")
	t_assert("mode", mode, t.union(t.literal("Entered"), t.literal("Exited")), "'Entered' | 'Exited'")
	t_assert("fn", fn, "callback")
	
	return self[`Item{mode}`]:Connect(function(item: Instance, metadata: Metadata?)
		if datatype ~= "LocalPlayer" and datatype ~= "BodyPart" then
			if not item:IsA(datatype) then return end
		elseif datatype == "LocalPlayer" then
			if item ~= Players.LocalPlayer then return end
		elseif datatype == "BodyPart" then
			if item.Parent and not item.Parent:FindFirstChildWhichIsA("Humanoid") then return end
		end

		fn(item, metadata)
	end)
end

--[[
	Copies an array of <code>BaseParts</code> to be replicated inside the query space. Returns the replicas
]]
function Zone.CopyToQuerySpace(self: Zone, parts: {BasePart}, static: boolean?, propertyReplicationWhitelist: {[string]: boolean}?): {BasePart}
	assert(self.QueryOptions.InSeperateQuerySpace, "InSeperateQuerySpace is not enabled")
	t_assert("parts", parts, T_TYPES.instArray, "{Instance}")
	t_assert("static", static, t.optional(t.boolean), "boolean?")
	t_assert("propertyReplicationWhitelist", propertyReplicationWhitelist, t.optional(t.map(t.string, t.boolean)), "{[string]: boolean}?")

	local returnedReplicas = table.create(#parts)
	for _, part in parts do
		copyToQuerySpace(self, part, static, propertyReplicationWhitelist, PART_BLACKLIST, returnedReplicas)
	end

	return returnedReplicas
end

--[[
	Removes all replicas of an array of <code>BaseParts</code> from the query space.
]]
function Zone.RemoveFromQuerySpace(self: Zone, originalParts: {BasePart}): ()
	assert(self.QueryOptions.InSeperateQuerySpace, "InSeperateQuerySpace is not enabled")
	t_assert("parts", originalParts, T_TYPES.instArray, "{Instance}")

	for _, part in originalParts do
		removeFromQuerySpace(self, part)
	end
end

--[[
	Gets all replicas of an array of <code>BaseParts</code>, optionally specifying if they are static or not so the function knows where to look.
]]
function Zone.GetReplicasOf(self: Zone, parts: {BasePart}, static: boolean?): {BasePart}
	assert(self.QueryOptions.InSeperateQuerySpace, "InSeperateQuerySpace is not enabled")
	t_assert("parts", parts, T_TYPES.instArray, "{Instance}")
	t_assert("static", static, t.optional(t.boolean), "boolean?")

	local querySpace = self.QuerySpace
	if not querySpace then return {} end
	local replicas = {}

	for i, part in parts do
		local zonePlace = static and querySpace.static or querySpace.dynamic
		local index = table.find(zonePlace.index, part)
		if index then
			table.insert(replicas, zonePlace.replicas[index])
		end
	end

	return replicas
end

--[[
	Makes this <code>Zone</code> use the query space of the <code>otherZone</code>, keeping the old one which can be restored by passing <code>otherZone</code> as "self".
]]
function Zone.UseQuerySpaceOf(self: Zone, otherZone: Zone | "self"): ()
	assert(self.QueryOptions.InSeperateQuerySpace, "InSeperateQuerySpace is not enabled")
	assert(otherZone ~= nil, "Bad otherZone argument")

	local queryOp = self.QueryOptions
	assert(not (not queryOp.InSeperateQuerySpace and otherZone == "self"), 
		"Cannot use query space of self because zone was not created in a seperate query space.")

	local querySpace, worldModel
	if otherZone == "self" then
		querySpace = self.OwnQuerySpace or self.QuerySpace
		worldModel = self.WorldRoot
	else
		querySpace = otherZone.QuerySpace
		worldModel = otherZone.WorldRoot
	end

	self.OwnQuerySpace = otherZone ~= "self" and self.QuerySpace or nil

	self.QuerySpace = querySpace
	self.WorldRoot = worldModel
end

--[[
	Overwrites this <code>Zone</code>s query space with the one of <code>otherZone</code>.
]]
function Zone.OverwriteQuerySpace(self: Zone, otherZone: Zone): ()
	assert(self.QueryOptions.InSeperateQuerySpace, "InSeperateQuerySpace is not enabled")
	assert(otherZone ~= nil, "Bad otherZone argument")

	local querySpace = self.QuerySpace
	if not querySpace then return end

	self:RemoveFromQuerySpace(querySpace.dynamic.index)
	self:RemoveFromQuerySpace(querySpace.static.index)
	self.WorldRoot:Destroy()

	self.QuerySpace = otherZone.QuerySpace
	self.WorldRoot = otherZone.WorldRoot
end

--[[
	Observes all items (baseparts) currently in the zone.
	Returns a cleanup function. All observers are automatically cleaned when the zone is destroyed.
]]
function Zone.ObserveItems(
	self: Zone,
	callback: (item: BasePart, metadata: Metadata?) -> ( () -> () )?,
	guard: ( (item: BasePart, metadata: Metadata?) -> (boolean) )?
): () -> ()
	local objAddedConn: any
	local objRemovedConn: any
	local handledObjects: { [BasePart]: boolean } = {}

	-- Map each child to its cleanup function
	local cleanupFunctionsPerObj: { [BasePart]: () -> () } = {}

	-- Choose the guard (either the one passed in, or a default that always returns true)
	local objGuard: (obj: BasePart) -> (boolean) = if guard ~= nil then guard else function() return true end

	local function onObjRemoved(obj: any, ...)
		handledObjects[obj] = nil
		local cleanup = cleanupFunctionsPerObj[obj]
		cleanupFunctionsPerObj[obj] = nil
		if typeof(cleanup) == "function" then
			task.spawn(cleanup)
		end
	end

	local function onObjAdded(obj: any, ...)
		-- skip if the observer was already disconnected
		if not objAddedConn.Connected then
			return
		end
		if handledObjects[obj] then
			-- already executed callback for this object
			return
		end
		handledObjects[obj] = true
		task.defer(function()
			handledObjects[obj] = nil
		end)

		if not objGuard(obj, ...) then
			return
		end

		-- Run the callback in protected mode:
		local success, cleanup = xpcall(function(child, ...)
			local clean = callback(child, ...)
			if clean ~= nil then
				assert(typeof(clean) == "function", "callback must return a function or nil")
			end
			return clean
		end, debug.traceback, obj :: any, ...)

		-- If callback errored, print out the traceback:
		if not success then
			local err = ""
			local firstLine = string.split(cleanup :: any, "\n")[1]
			local lastColon = string.find(firstLine, ": ")
			if lastColon then
				err = firstLine:sub(lastColon + 1)
			end
			warn(`error while calling ObserveItems() callback:{err}\n{cleanup}`)
			return
		end

		if cleanup then
			-- only keep the cleanup if we're still observing
			if objAddedConn.Connected then
				cleanupFunctionsPerObj[obj] = cleanup
			else
				-- otherwise run it immediately
				task.spawn(cleanup)
			end
		end
	end

	objAddedConn = self.ItemEntered:Connect(onObjAdded)
	objRemovedConn = self.ItemExited:Connect(onObjRemoved)

	-- Fire for existing objects
	for _, obj in ipairs(self:Query()) do
		task.defer(onObjAdded, obj)
	end

	-- Return a disconnect function
	local function cleanup()
		objAddedConn:Disconnect()
		objRemovedConn:Disconnect()
		-- Clean up any remaining objects
		for obj, _ in pairs(cleanupFunctionsPerObj) do
			onObjRemoved(obj)
		end
		local index = table.find(self.ActiveObservers, cleanup)
		if index then
			table.remove(self.ActiveObservers, index)
		end
	end
	table.insert(self.ActiveObservers, cleanup)
	return cleanup
end

--[[
	Disconnects all connections related to this <code>Zone</code> and cleans up any associated <code>Instance</code> references.
]]
function Zone.Destroy(self: Zone): ()
	self:UnbindFromHeartbeat()
	
	local bin = self.Trash
	local tracked = self.TrackerConnections
	local replica = self.ReplicaConnections
	local observers = self.ActiveObservers
	
	for _, v in bin do
		if typeof(v) == "Instance" then
			v:Destroy()
		elseif typeof(v) == "RBXScriptConnection" then
			v:Disconnect()
		end
	end
	for _, v in tracked do
		v:Disconnect()
	end
	for _, v in replica do
		for _, w in v do
			if not w then continue end
			w:Disconnect()
		end
	end
	for _, cleanup in observers do
		task.spawn(cleanup)
	end
	
	task.defer(function()
		self.ItemEntered:Destroy()
		self.ItemExited:Destroy()
	end)
end

type ZoneImpl = {
	Query: typeof(
		--[[
			A replaceable callback function that the <code>Zone</code> calls whenever querying the <code>Zone</code>.
		]]
		function(self: Zone, params: OverlapParams?): {any}
			return {}
		end
	),
	
	TrackerConnections: {[any]: RBXScriptConnection},
	ReplicaConnections: {[any]: {RBXScriptConnection?}},

	Items: {[any]: boolean | Metadata},
	StoredClasses: {[string]: {any}},
	Tracked: {[any]: boolean},
	Trash: {any},
	ActiveObservers: { () -> () },
	
	QueryOptions: QueryOptions,
	QuerySpace: QuerySpace?,
	OwnQuerySpace: QuerySpace?,
	LastUpdate: number,

	WorldRoot: WorldRoot,

	ItemExited: Signal.RBXScriptSignal<Instance, Metadata?>,
	ItemEntered: Signal.RBXScriptSignal<Instance, Metadata?>
}

export type Zone = typeof(Zone) & ZoneImpl

local function zone_new<T>(queryOp: QueryOptions, ...)
	local bin = {...}
	local zone = {
		-- Tables with [Instance]: RBXScriptConnection pairs to track connections
		TrackerConnections	= {},
		ReplicaConnections	= {},
		ActiveObservers = {},
		
		-- Main
		Items 			= {},
		StoredClasses	= {},
		Tracked			= {},
		Trash			= bin,
		QueryOptions 	= queryOp,
		LastUpdate		= os.clock(),
		
		WorldRoot		= workspace,
		
		ItemEntered 	= Signal.new(),
		ItemExited 		= Signal.new(),
		
		Update 				= Zone.Update,
		BindToHeartbeat 	= Zone.BindToHeartbeat,
		UnbindFromHeartbeat = Zone.UnbindFromHeartbeat,
		TrackItem			= Zone.TrackItem,
		UntrackItem			= Zone.UntrackItem,
		GetItemsWhichAreA	= Zone.GetItemsWhichAreA,
		SearchFor			= Zone.SearchFor,
		ListenTo			= Zone.ListenTo,
		ObserveItems 		= Zone.ObserveItems,
		
		CopyToQuerySpace	= Zone.CopyToQuerySpace,
		RemoveFromQuerySpace= Zone.RemoveFromQuerySpace,
		GetReplicasOf		= Zone.GetReplicasOf,
		UseQuerySpaceOf		= Zone.UseQuerySpaceOf,
		OverwriteQuerySpace = Zone.OverwriteQuerySpace,
		
		Destroy				= Zone.Destroy
	} :: Zone
	
	if queryOp.InSeperateQuerySpace and queryOp.QuerySpace == nil then
		local model = Instance.new("WorldModel")
		model.Name = "SimpleZone_QuerySpace"
		model.Parent = worldContainer
		table.insert(bin, model)
		
		-- Internal query space
		zone.WorldRoot = model
		zone.QuerySpace = {
			dynamic = {
				index = {},
				replicas = {}
			},
			
			static = {
				index = {},
				replicas = {}
			},
		}
	elseif queryOp.QuerySpace ~= nil then
		assert(queryOp.QuerySpace.World ~= nil and queryOp.QuerySpace.Space ~= nil, "Missing world/space fields for QuerySpace")
		zone.WorldRoot = queryOp.QuerySpace.World
		zone.QuerySpace = queryOp.QuerySpace.Space
	end
	
	return zone
end

-- Creates a new <code>Zone</code> based on a <code>BasePart</code>.
local function zone_fromPart(part: BasePart, queryOp: QueryOptions?): Zone
	t_assert("part", part, t.instance("BasePart"), "BasePart")
	
	local queryOp = queryOp or queryop_new()
	assertQueryOp(queryOp)
	
	local zone = zone_new(queryOp)
	if queryOp.InSeperateQuerySpace then
		part = copyToQuerySpace(zone, part, queryOp.Static, PART_WHITELIST, PART_BLACKLIST)
	end
	
	function zone:Query(params)
		local worldModel = self.WorldRoot
		if part:IsA("Part") then
			local fn = PartQueryJumpTable[part.Shape.Name]
			return fn and fn(worldModel, part, params) or worldModel:GetPartsInPart(part, params)
		end
		
		return worldModel:GetPartsInPart(part, params)
	end
	
	return zone
end

-- Creates a new <code>Zone</code> based on an bounding box.
local function zone_fromBox(cframe: CFrame, size: Vector3, queryOp: QueryOptions?): Zone
	t_assert("cframe", cframe, "CFrame")
	t_assert("size", size, "vector")
	
	local queryOp = queryOp or queryop_new()
	assertQueryOp(queryOp)
	
	local zone = zone_new(queryOp)
	
	function zone:Query(params)
		return self.WorldRoot:GetPartBoundsInBox(cframe, size, params)
	end
	
	return zone
end

-- Creates a new <code>Zone</code> based on an array of bounding boxes.
local function zone_fromBoxes(boxes: {Box}, queryOp: QueryOptions?): Zone
	t_assert("boxes", boxes, T_TYPES.boxArray, "{Box}")
	
	local queryOp = queryOp or queryop_new()
	assertQueryOp(queryOp)
	
	local zone = zone_new(queryOp)
	
	function zone:Query(params)
		local queryOp = self.QueryOptions
		local querySpace = self.QuerySpace
		local worldModel = self.WorldRoot
		local result: any = {}
		
		for _, box in boxes do
			local query = worldModel:GetPartBoundsInBox(box.cframe, box.size::any, params)
			if #query == 0 then continue end
			
			if self.QueryOptions.AcceptMetadata then
				for _, item in query do
					table.insert(result, {item = item, metadata = {box = box}})
				end
			else
				table.move(query, 1, #query, #result + 1, result)
			end
		end

		return result
	end
	
	return zone
end

-- Creates a new <code>Zone</code> based on an array of <code>BaseParts</code>.
local function zone_fromParts(parts: {BasePart}, queryOp: QueryOptions?): Zone
	t_assert("parts", parts, T_TYPES.partArray, "{BasePart}")
	
	local queryOp = queryOp or queryop_new()
	assertQueryOp(queryOp)
	
	local boxes: {Box}
	
	local zone = zone_new(queryOp)
	if queryOp.InSeperateQuerySpace then
		local replicas = zone:CopyToQuerySpace(parts, queryOp.Static, PART_WHITELIST)
		boxes = getBoxesFromParts(replicas)
	else
		boxes = getBoxesFromParts(parts)
	end
	
	local cf, size = getBoundingBox(boxes)
	
	function zone:Query(params)
		debug.profilebegin("SimpleZone::FromParts")
		local querySpace = self.QuerySpace
		local queryOp = self.QueryOptions
		local worldModel = self.WorldRoot

		local zonePlace = if querySpace ~= nil then (queryOp.Static and querySpace.static or querySpace.dynamic) else nil
		local result: {any} = {}
		
		local wholeCheck = worldModel:GetPartBoundsInBox(cf, size::any, params)
		if #wholeCheck == 0 then
			debug.profileend()
			return result 
		end
		
		for _, part in parts do
			local query: {BasePart}
			if part:IsA("Part") then
				local fn = PartQueryJumpTable[part.Shape.Name]
				query = fn and fn(worldModel, part, params) or worldModel:GetPartsInPart(part, params)
			else
				query = worldModel:GetPartsInPart(part, params)
			end

			if queryOp.AcceptMetadata then
				if queryOp.InSeperateQuerySpace and zonePlace then
					local index = table.find(zonePlace.replicas, part)
					if index then
						part = zonePlace.index[index]
					end
				end
				
				for _, item in query do
					table.insert(result, {item = item, metadata = {part = part}})
				end
			else
				table.move(query, 1, #query, #result + 1, result)
			end
		end
		debug.profileend()

		return result
	end
	
	return zone
end

-- Creates a new <code>Zone</code> based on a <code>part</code>. Does queries in parallel.
local function zone_fromPartParallel(part: BasePart, queryOp: QueryOptions?): Zone
	t_assert("part", part, t.instance("BasePart"), "BasePart")
	
	local queryOp = queryOp or queryop_new()
	assertQueryOp(queryOp)
	
	local worker = workerTemplate:Clone()
	worker.Parent = actorContainer

	local resultEvent = worker.Result

	local zone = zone_new(queryOp, worker)
	if queryOp.InSeperateQuerySpace then
		part = copyToQuerySpace(zone, part, queryOp.Static, PART_WHITELIST, PART_BLACKLIST)
	end
	
	function zone:Query(params)
		local worldModel = self.WorldRoot
		task.defer(worker.SendMessage, worker, "Query", worldModel, params, part)
		return resultEvent.Event:Wait()
	end
	
	return zone
end

-- Creates a new <code>Zone</code> using a custom query function <code>queryFn</code>.
local function zone_fromCustom(queryFn: (self: Zone, params: OverlapParams?) -> {{item: any, metadata: Metadata} | any | Instance}, queryOp: QueryOptions?): Zone
	assert(queryFn ~= nil, "Bad queryFn argument.")
	local queryOp = queryOp or queryop_new()
	assertQueryOp(queryOp)
	
	local zone = zone_new(queryOp)
	zone.Query = queryFn
	
	return zone
end

-- holy christ
local zone_new_overload: 
	typeof(zone_fromPart) & typeof(zone_fromBox) & typeof(zone_fromParts) & typeof(zone_fromBoxes) 
= function(a: {BasePart} | {Box} | CFrame | Instance, b: (QueryOptions | Vector3)?, c: QueryOptions?)
	
	if #(a::any) > 0 then
		if typeof((a :: {BasePart})[1]) == "Instance" and (a :: {BasePart})[1]:IsA("BasePart") then
			return zone_fromParts(a :: {BasePart}, b :: QueryOptions?)
		elseif typeof((a :: {Box})[1]) == "table" then
			return zone_fromBoxes(a :: {Box}, b :: QueryOptions?)
		else
			error("Unable to find an overload.")
		end
	end
	
	if typeof(a) == "CFrame" and typeof(b) == "Vector3" then
		return zone_fromBox(a, b, c)
	elseif typeof(a) == "Instance" and a:IsA("BasePart") then
		return zone_fromPart(a, b)
	else
		error("Unable to find an overload.")
	end
end

local lpOnly = script:GetAttribute("ClientOnlyDetectLocalPlayer")
if lpOnly and RunService:IsClient() then
	Tracker.onPlayerAdded(Players.LocalPlayer)
else
	Tracker.startPlayerTracking()
end
Tracker.startItemTracking()

return table.freeze {
	new = zone_new_overload,
	fromBox = zone_fromBox,
	fromPart = zone_fromPart,
	fromParts = zone_fromParts,
	fromBoxes = zone_fromBoxes,
	fromCustom = zone_fromCustom,
	fromPartParallel = zone_fromPartParallel,
	
	QueryOptions = {
		new = queryop_new
	}
}