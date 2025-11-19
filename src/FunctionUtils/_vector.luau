local PathfindingService = game:GetService("PathfindingService")
local Vector = {}

function Vector.distance(position0: Vector3, position1: Vector3)
	assert(position0 and typeof(position0) == "Vector3", "Position0 is invalid or nil")
	assert(position1 and typeof(position1) == "Vector3", "Position1 is invalid or nil")

	local p = position0 - position1
	local magnitude = p.Magnitude

	return magnitude
end

function Vector.pathDistance(position0: Vector3, position1: Vector3, agentOptions: {})
	assert(position0 and typeof(position0) == "Vector3", "Position0 is invalid or nil")
	assert(position1 and typeof(position1) == "Vector3", "Position1 is invalid or nil")

	local path = PathfindingService:CreatePath(agentOptions)
	path:ComputeAsync(position0, position1)

	local totalDistance = 0

	local waypoints = path:GetWaypoints()
	for i, waypoint in pairs(waypoints) do
		if not waypoints[i + 1] then return end
		totalDistance += Vector.distance(waypoint.Position, waypoints[i + 1].Position)
	end

	return totalDistance
end

function Vector.direction(position0: Vector3, position1: Vector3)
	assert(position0 and typeof(position0) == "Vector3", "Position0 is invalid or nil")
	assert(position1 and typeof(position1) == "Vector3", "Position1 is invalid or nil")

	local p = position0 - position1
	return p
end

function Vector.limit(xPosition: Vector3, minPosition: Vector3, maxPosition: Vector3)
	assert(xPosition and typeof(xPosition) == "Vector3", "xPosition is invalid or nil")
	assert(minPosition and typeof(minPosition) == "Vector3", "minPosition is invalid or nil")
	assert(maxPosition and typeof(maxPosition) == "Vector3", "maxPosition is invalid or nil")

	local X, Y, Z = xPosition.X, xPosition.Y, xPosition.Z

	local minX, minY, minZ = minPosition.X, minPosition.Y, minPosition.Z
	local maxX, maxY, maxZ = maxPosition.X, maxPosition.Y, maxPosition.Z

	local newVector = Vector3.new(
		math.clamp(X, minX, maxX),
		math.clamp(Y, minY, maxY),
		math.clamp(Z, minZ, maxZ)
	)

	return newVector
end

function Vector.getPositionInFrontOf(object: BasePart, offsetStuds: number): Vector3
	assert(object and object:IsA("BasePart"), "object is invalid or nil")
	assert(offsetStuds and typeof(offsetStuds) == "number", "object is invalid or nil")
	
	return object.Position + object.CFrame.LookVector * offsetStuds
end

return Vector