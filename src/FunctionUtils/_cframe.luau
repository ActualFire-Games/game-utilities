--!strict
--@author: crusherfire
--@date: 11/18/25
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Grabs the orientation of the CFrame and stores it in a Vector3 (in degrees).
function Module.getOrientation(cframe: CFrame): Vector3
	assert(cframe, "cframe is invalid or nil")
	local rx, ry, rz = cframe:ToOrientation()
	return Vector3.new(math.deg(rx), math.deg(ry), math.deg(rz))
end

-- Returns a CFrame.Angles that represents a rotation on the specified axis that is oriented towards lookAt along with the radian rotation value.
function Module.getLookRotation(axis: "X" | "Y", origin: Vector3, lookAt: Vector3): (CFrame, number)
	local unit = origin - lookAt
	if axis == "X" then
		local angle = math.atan2(unit.Y, unit.Z)
		return CFrame.Angles(-angle, 0, 0), -angle
	elseif axis == "Y" then
		local angle = math.atan2(unit.X, unit.Z)
		return CFrame.Angles(0, angle, 0), angle
	else
		error(`Invalid axis: {axis}`, 2)
	end
end

-- Aligns vector <code>a</code> to vector <code>b</code> by giving a CFrame rotation in world-space that represents the smallest rotation to get there.
function Module.cframeFromTo(a: Vector3, b: Vector3): CFrame
	local dr = a:Dot(b)
	local di = a:Cross(b)

	local d = math.sqrt(dr*dr + di:Dot(di))
	if d < 1e-6 then
		return CFrame.identity
	end

	if dr < 0 and -di.Magnitude/dr < 1e-6 then
		-- this is a degenerate case where a ~ -b
		-- so we must arbitrate a perpendicular axis to a and b to disambiguate.
		local r = b - a
		local r2 = r*r
		local min = math.min(r2.X, r2.Y, r2.Z)
		if min == r2.X and min == r2.Y then

			return CFrame.new(0, 0, 0, 0, 0, r.Z, 0)
		elseif min == r2.Y and min == r2.Z then
			return CFrame.new(0, 0, 0, 0, r.X, 0, 0)
		elseif min == r2.X and min == r2.Z then
			return CFrame.new(0, 0, 0, r.Y, 0, 0, 0)
		elseif min == r2.X then
			return CFrame.new(0, 0, 0, 0, -r.Z, r.Y, 0)
		elseif min == r2.Y then
			return CFrame.new(0, 0, 0, r.Z, 0, -r.X, 0)
		else --if min == r2.Z then
			return CFrame.new(0, 0, 0, -r.Y, r.X, 0, 0)
		end
	end

	return CFrame.new(0, 0, 0, di.X, di.Y, di.Z, dr + d)
end

-- Returns a CFrame that keeps only the rotation of <code>cframe</code>.
function Module.onlyRotation(cframe: CFrame): CFrame
	return cframe - cframe.Position
end

--[[
	Returns a CFrame which is minimally rotated from <code>cframe</code> such that the following condition is true:
	<code>returnedCFrame:VectorToWorldSpace(localAxis) == worldGoal</code>
	AKA: You take one of a local axis (-Vector3.xAxis, Vector3.yAxis, etc) and reorient it so that this local-axis points
	exactly in the direction of <code>worldGoal</code> (in world-space).
]]
function Module.redirectLocalAxis(cframe: CFrame, localAxis: Vector3, worldGoal: Vector3): CFrame
	local localGoal = cframe:VectorToObjectSpace(worldGoal)
	local m = localAxis.Magnitude * localGoal.Magnitude
	local d = localAxis:Dot(localGoal)
	local c = localAxis:Cross(localGoal)
	local R = CFrame.new(0, 0, 0, c.X, c.Y, c.Z, d + m)

	if R == R then
		return cframe * R
	else
		return cframe
	end
end

-- Returns a CFrame from an axis angle, handling NaN values.
-- <strong>axisAngle</strong>: A Vector3 that represents the axis to rotate around as well as how much to
-- rotate around that axis (based on its <code>Magnitude</code>).
-- <code>axisAngle == a * b</code> where <code>a</code> is a unit vector and <code>b</code> is the rotation in radians.
-- <strong>position</strong>: Provide an optional positional value for the CFrame.
function Module.axisAngleToCFrame(axisAngle: Vector3, position: Vector3?): CFrame
	local angle = axisAngle.Magnitude
	local cframe = CFrame.fromAxisAngle(axisAngle, angle)

	if cframe ~= cframe then
		if position then
			return CFrame.new(position)
		else
			return CFrame.new()
		end
	end

	if position then
		cframe = cframe + position
	end

	return cframe
end

--[[
	Constructs a CFrame from a <code>position</code>, <code>upVector</code>, and <code>rightVector</code> even if these
	upVector and rightVectors are not orthogonal to each other.
]]
function Module.fromUpRight(position: Vector3, upVector: Vector3, rightVector: Vector3): CFrame?
	local forwardVector = rightVector:Cross(upVector)
	if forwardVector.Magnitude == 0 then
		return nil
	end

	forwardVector = forwardVector.Unit
	local rightVector2 = forwardVector:Cross(upVector)

	return CFrame.fromMatrix(position, rightVector2, upVector)
end

-- Scales the positional component of <code>cframe</code>.
function Module.scalePosition(cframe: CFrame, scale: number): CFrame
	if scale == 1 then
		return cframe
	else
		local position = cframe.Position
		return cframe - position + position*scale
	end
end

function Module.mirror(cframe: CFrame, mirror: CFrame): CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = mirror:ToObjectSpace(cframe):GetComponents()
	-- Reflect along X/Y plane (Z axis).
	local reflection = CFrame.new(
		x, y, -z,
		-r00, r01, r02,
		-r10, r11, r12,
		r20, -r21, -r22
	)
	return mirror:ToWorldSpace(reflection)
end

-----------------------------
-- MAIN --
-----------------------------
return Module