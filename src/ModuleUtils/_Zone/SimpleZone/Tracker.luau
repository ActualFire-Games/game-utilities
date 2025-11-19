--!optimize 2
--!strict

local Players = game:GetService('Players')

local partToPlayer: {[BasePart]: Player} = {}
local connectionTracker: {[Player]: {RBXScriptConnection}} = {}
local characterAddedConnections: { [Player]: RBXScriptConnection } = {}
-- All items to be queried
local items: {BasePart} = {}
-- Cache part volume so we don't have to recompute it every time an instance is added/removed from the workspace
local itemVolumeMap: { [BasePart]: number } = {}
local itemIndex: { [BasePart]: number } = {}
local sizeChangedConnections: { [BasePart]: RBXScriptConnection } = {}
local canQueryConnections: { [BasePart]: RBXScriptConnection } = {}

local totalVolume = 0

local function computeVolume(part: BasePart): number
	local size = part.Size
	return size.X * size.Y * size.Z
end

local function addTrackedPart(part: BasePart, owner: Player?)
	if itemIndex[part] then
		return
	end
	
	local volume = computeVolume(part)
	itemVolumeMap[part] = volume
	totalVolume += volume
	
	local itemsLength = #items
	local newIndex = itemsLength + 1
	items[newIndex] = part
	itemIndex[part] = newIndex
	
	if owner then
		partToPlayer[part] = owner
	end
	
	sizeChangedConnections[part] = part:GetPropertyChangedSignal("Size"):Connect(function()
		local oldVolume = itemVolumeMap[part] or 0
		local newVolume = computeVolume(part)
		itemVolumeMap[part] = newVolume
		totalVolume += (newVolume - oldVolume)
	end)
end

local function removeTrackedPart(part: BasePart)
	-- ALWAYS clean up any potential connections
	local sizeConn = sizeChangedConnections[part]
	if sizeConn then
		sizeConn:Disconnect()
		sizeChangedConnections[part] = nil
	end
	local queryConn = canQueryConnections[part]
	if queryConn then
		queryConn:Disconnect()
		canQueryConnections[part] = nil
	end
	
	local index = itemIndex[part]
	if not index then
		return
	end
	
	totalVolume -= itemVolumeMap[part] or 0
	itemVolumeMap[part] = nil
	
	local itemsLength = #items
	local lastPart = items[itemsLength]
	items[index] = lastPart
	itemIndex[lastPart] = index
	
	items[itemsLength] = nil
	itemIndex[part] = nil
	partToPlayer[part] = nil
end

local function watchCanQuery(part: BasePart, owner: Player?)
	if canQueryConnections[part] then
		return
	end
	
	canQueryConnections[part] = part:GetPropertyChangedSignal("CanQuery"):Connect(function()
		if part.CanQuery then
			addTrackedPart(part, owner)
		else
			removeTrackedPart(part)
		end
	end)
end

local function handleCharacterUpdate(player: Player, character: Model)
	for _, v in connectionTracker[player] do
		v:Disconnect()
	end
	table.clear(connectionTracker[player])
	for part, owner in partToPlayer do
		if owner ~= player then continue end
		removeTrackedPart(part)
	end
	
	for _, descendant in character:GetDescendants() do
		if not descendant:IsA("BasePart") then continue end
		watchCanQuery(descendant, player)
		if descendant.CanQuery then
			addTrackedPart(descendant, player)
		end
	end
	
	table.insert(connectionTracker[player], character.DescendantAdded:Connect(function(descendant)
		if not descendant:IsA("BasePart") then return end
		watchCanQuery(descendant, player)
		if descendant.CanQuery then
			addTrackedPart(descendant, player)
		end
	end))
	
	table.insert(connectionTracker[player], character.DescendantRemoving:Connect(function(descendant)
		if not descendant:IsA("BasePart") then return end
		removeTrackedPart(descendant)
	end))
end

local function onPlayerAdded(player)
	connectionTracker[player] = {}
	
	characterAddedConnections[player] = player.CharacterAdded:Connect(function(character)
		handleCharacterUpdate(player, character)
	end)
	
	if player.Character then
		handleCharacterUpdate(player, player.Character)
	end
end

local function onPlayerRemoving(player)
	for _, v in connectionTracker[player] do
		v:Disconnect()
	end
	connectionTracker[player] = nil
	local connection = characterAddedConnections[player]
	if connection then
		connection:Disconnect()
		characterAddedConnections[player] = nil
	end
	
	for part, owner in partToPlayer do
		if owner ~= player then continue end
		removeTrackedPart(part)
	end
end

local function startPlayerTracking()
	local playerAdded = Players.PlayerAdded:Connect(onPlayerAdded)
	local playerRemoving = Players.PlayerRemoving:Connect(onPlayerRemoving)
	
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	return playerAdded, playerRemoving
end

local function startItemTracking()
	workspace.DescendantAdded:Connect(function(descendant: BasePart)
		if not descendant:IsA("BasePart") then return end
		watchCanQuery(descendant)
		if descendant.CanQuery then
			addTrackedPart(descendant)
		end
	end)
	workspace.DescendantRemoving:Connect(function(descendant: BasePart)
		if not descendant:IsA("BasePart") then return end
		removeTrackedPart(descendant)
	end)
end

local function getTotalVolume()
	return totalVolume
end

return {
	characterObjects = partToPlayer,
	startPlayerTracking = startPlayerTracking,
	startItemTracking = startItemTracking,
	
	onPlayerAdded = onPlayerAdded,
	onPlayerRemoving = onPlayerRemoving,
	
	getTotalVolume = getTotalVolume,
	
	items = items
}