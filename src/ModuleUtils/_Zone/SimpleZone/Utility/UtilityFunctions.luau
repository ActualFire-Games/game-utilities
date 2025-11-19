--!optimize 2
--!strict

local Players = game:GetService("Players")

local t = require("./t")

local QUERY_SPACE_VALIDATOR = t.interface {
	dynamic = t.interface {
		index = t.array(t.instance("BasePart")),
		replicas = t.array(t.instance("BasePart"))
	},

	static = t.interface {
		index = t.array(t.instance("BasePart")),
		replicas = t.array(t.instance("BasePart"))
	}
}
local QUERY_OPTIONS_VALIDATOR = t.interface {
	FireMode = t.union(
		t.literal("OnEnter"),
		t.literal("OnExit"),
		t.literal("Both"),
		t.literal("None")
	),
	TrackItemEnabled = t.boolean,
	StoreByClass = t.boolean,
	AcceptMetadata = t.boolean,
	UpdateInterval = t.number,
	InSeperateQuerySpace = t.boolean,
	Static = t.boolean,
	QuerySpace = t.optional(t.interface {
		Space = QUERY_SPACE_VALIDATOR,
		World = t.instance("WorldRoot")
	})
}

local T_TYPES = {
	boxArray = t.array(t.interface {
		cframe = t.CFrame,
		size = t.vector
	}),
	partArray = t.array(t.instance("BasePart")),
	instArray = t.array(t.Instance)
}

local rbxget: (inst: Instance, prop: string) -> any do
	xpcall(function()
		return game[""]
	end, function()
		rbxget = debug.info(2, "f")
	end)
end

local rbxset: (inst: Instance, prop: string, value: any) -> () do
	xpcall(function()
		game[""] = nil
	end, function()
		rbxset = debug.info(2, "f")
	end)
end

local function getParamsForPlayerCharacters(zone)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	local characters = {}
	for _, player in Players:GetPlayers() do
		if not player.Character then continue end
		table.insert(characters, player.Character)
		if zone.QueryOptions.InSeperateQuerySpace then
			local replicas = zone:GetReplicasOf(player.Character:GetChildren())
			table.move(replicas, 1, #replicas, #characters + 1, characters)
		end
	end

	params.FilterDescendantsInstances = characters
	return params
end

local function updateClassStorage(self: any, item, isEntering: boolean)
	local vtype = typeof(item)
	local class = vtype == "Instance" and item.ClassName or vtype

	if isEntering then
		-- Add item to class storage
		local classes = self.StoredClasses[class]
		if not classes then
			classes = {}
			self.StoredClasses[class] = classes
		end
		classes[#classes + 1] = item
	else
		-- Remove item from class storage
		local classes = self.StoredClasses[class]
		if classes then
			local index = table.find(classes, item)
			if index then
				table.remove(classes, index)
				if #classes == 0 then
					self.StoredClasses[class] = nil
				end
			end
		end
	end
end

local function removeFromQuerySpace(self: any, part: BasePart)
	if not part:IsA("BasePart") then return end
	local querySpace = self.QuerySpace
	if not querySpace then return end

	local connections = self.ReplicaConnections

	for _, c in connections[part] do
		if not c then continue end
		c:Disconnect()
	end

	local index: number?, tbl
	local staticIndex = table.find(querySpace.static.index, part)
	if staticIndex then
		index = staticIndex
		tbl = querySpace.static
	else
		index = table.find(querySpace.dynamic.index, part)
		tbl = querySpace.dynamic
	end
	if not index then return end

	table.remove(tbl.index, index)
	table.remove(tbl.replicas, index)
end

local function copyToQuerySpace(self: any, part: BasePart, static: boolean?, propertyReplicationWhitelist: any, partBlacklist: any, returnedReplicas: {}?)
	if not part:IsA("BasePart") then return end
	local querySpace = self.QuerySpace
	if not querySpace then return end

	local worldModel = self.WorldRoot
	local connections = self.ReplicaConnections

	local indexTable = static and querySpace.static.index or querySpace.dynamic.index
	local replicas = static and querySpace.static.replicas or querySpace.dynamic.replicas

	--local returnedReplicas = table.create(#parts)
	local index = #replicas + 1

	local replica = Instance.fromExisting(part)
	replica.Name = `REPLICA[{index}]({part.Name})`
	replica.Anchored = true
	replica.Parent = worldModel

	indexTable[index] = part
	replicas[index] = replica

	connections[part] = {
		if propertyReplicationWhitelist ~= nil then part.Changed:Connect(function(property)
			if partBlacklist[property] then return end
			if not propertyReplicationWhitelist[property] then return end
			
			rbxset(replica, property, rbxget(part, property))
		end) else nil,
		part.Destroying:Once(function()
			removeFromQuerySpace(self, part)
		end)
	}

	if returnedReplicas then
		table.insert(returnedReplicas, replica)
	end
	return replica
end

local function getBoxesFromParts(parts): {any}
	local boxes = {}
	for _, part in parts do
		local pos = part.Position
		local size = part.Size
		table.insert(boxes, {
			cframe = part.CFrame.Rotation + pos,
			size = size,
			part = part
		})
	end

	return boxes
end

return {
	QuerySpaceValidator = QUERY_SPACE_VALIDATOR,
	QueryOptionsValidator = QUERY_OPTIONS_VALIDATOR,
	TTypes = T_TYPES,
	
	defaultParamGenerator = getParamsForPlayerCharacters,
	updateClassStorage = updateClassStorage,
	removeFromQuerySpace = removeFromQuerySpace,
	copyToQuerySpace = copyToQuerySpace,
	getBoxesFromParts = getBoxesFromParts
}