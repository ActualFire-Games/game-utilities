local _Random = {}

local rng = Random.new(tick())

-- <strong>percentChance</strong>: Should be a value between 0-100.
-- <strong>luck</strong>: Represents how many rerolls.
function _Random.rollChance(percentChance: number, luck: number?): boolean
	if percentChance <= 0 then
		return false
	end
	luck = luck or 0
	local rolls = math.ceil(math.abs(luck :: number))
	local num2 = rng:NextNumber(0, 100)

	for i = 1, rolls do
		local b = rng:NextNumber(0, 100)
		num2 = if luck > 0 then math.min(num2, b) else math.max(num2, b)
	end
	if num2 <= percentChance then
		return true
	end
	return false
end

function _Random.range(minF: number, maxF: number, seed: number?): number
	assert(minF and typeof(minF) == "number", "minF is invalid or nil")
	assert(maxF and typeof(maxF) == "number", "maxF is invalid or nil")

	local RBLX_Random = Random.new(seed or math.random() * 1000000)
	local randomValue = RBLX_Random:NextInteger(minF, maxF)

	return randomValue
end

function _Random.positionInPart(part: BasePart): Vector3
	assert(part and part:IsA("BasePart"), "First argument must be a valid BasePart")

	local size = part.Size
	local halfX, halfY, halfZ = size.X / 2, size.Y / 2, size.Z / 2

	-- Random offset inside the bounding box (in local space)
	local offsetX = math.random() * size.X - halfX
	local offsetY = math.random() * size.Y - halfY
	local offsetZ = math.random() * size.Z - halfZ

	local localOffset = Vector3.new(offsetX, offsetY, offsetZ)

	-- Convert local offset to world space, accounting for part rotation and position
	local worldPosition = part.CFrame:PointToWorldSpace(localOffset)

	return worldPosition
end

function _Random.cFrameInPart(part: BasePart): CFrame
	assert(part and part:IsA("BasePart"), "Argument must be a valid BasePart")

	local size = part.Size
	local halfX, halfY, halfZ = size.X / 2, size.Y / 2, size.Z / 2

	-- Generate random local position within the part's bounds
	local localOffset = Vector3.new(
		math.random() * size.X - halfX,
		math.random() * size.Y - halfY,
		math.random() * size.Z - halfZ
	)

	-- Generate a completely random rotation
	local randomRotation = CFrame.Angles(
		math.rad(math.random(0, 359)), -- X rotation
		math.rad(math.random(0, 359)), -- Y rotation
		math.rad(math.random(0, 359))  -- Z rotation
	)

	-- Combine the part's CFrame, position offset, and random rotation
	local worldCFrame = part.CFrame * CFrame.new(localOffset) * randomRotation

	return worldCFrame
end

function _Random.object(objectsList: {} | Instance, recursive: boolean)
	assert(objectsList and typeof(objectsList) == "table" or typeof(objectsList) == "Instance", "objectsList is invalid or nil")

	local list = typeof(objectsList) == "Instance" and (recursive and objectsList:GetDescendants() or objectsList:GetChildren()) or objectsList
	local randomObject = list[_Random.range(1, #list)]

	return randomObject
end

function _Random.randomString(length: number, includeCapitals: boolean)
	local random = Random.new()
	local letters = {'a','b','c','d','e','f','g','h','i','j','k','l','m','n','o','p','q','r','s','t','u','v','w','x','y','z'}

	local function getRandomLetter()
		return letters[random:NextInteger(1,#letters)]
	end


	local length = length or 10
	local str = ''
	for i = 1, length do
		local randomLetter = getRandomLetter()
		if includeCapitals and random:NextNumber() > .5 then
			randomLetter = string.upper(randomLetter)
		end
		str = str .. randomLetter
	end
	return str
end

return _Random
