--!strict
--!native
local _easingDirection = require(script._easingDirection)
local _easingStyle = require(script._easingStyle)
local t = require("./_t")

local Module = {}
Module.EasingDirection = _easingDirection
Module.EasingStyle = _easingStyle

local PI = math.pi
local TAU = 2 * PI
local HUGE = math.huge
local rng = Random.new(tick())

local abs, clamp, min, max, rad, deg, pow, log = math.abs, math.clamp, math.min, math.max, math.rad, math.deg, math.pow, math.log
local sin, cos, tan, asin, acos, atan2 = math.sin, math.cos, math.tan, math.asin, math.acos,  math.atan2

local vect3New, vect2New, cfNew = Vector3.new, Vector2.new, CFrame.new

local vector = vector

--[[
	Returns a seed for use in random number generators.
	Seed is based on <code>os.time() + os.clock()</code>.
]]
function Module.getRngSeed(): number
	return os.time() + os.clock()
end

--[[
	Returns the value of the largest axis.
]]
function Module.getLargestAxis(v: Vector3): (number, "X" | "Y" | "Z")
	local absX, absY, absZ = abs(v.X), abs(v.Y), abs(v.Z)

	if absX >= absY and absX >= absZ then
		return v.X, "X"
	elseif absY >= absZ then
		return v.Y, "Y"
	else
		return v.Z, "Z"
	end
end

--[[
	Returns the correct angle that represents the shortest angular path between current and goal.
	This can help prevents issues like 360 degree flips in springs.
]]
function Module.alignAngle(current: number, goal: number): number
	local diff = (goal - current + PI) % TAU - PI
	return current + diff
end

--[[
	Given a float, like 1.75, returns the integer representation as a percentage.
	Example: 1.75 -> 75, 0.25 -> -75
	<strong>decimals</code> How many decimals to include in the percentage. Default is none.
]]
function Module.getMultiplierPercentange(x: number, decimals: number?): number
	local percentage = (x - 1) * 100

	if decimals then
		local factor = 10 ^ decimals
		return math.round(percentage * factor) / factor
	end

	return math.round(percentage)
end

--[[
	Attempts to derive an integer denominator for <code>x</code>.
	Example: 0.001 -> 1000
	<strong>tolerance</strong>: Default is 1e-9
]]
function Module.getDenominatorFromProbability(x: number, tolerance: number?): number?
	assert(t.number(x))
	assert(t.optional(t.number)(tolerance))

	if x <= 0 then
		return nil
	end

	local tolerance = tolerance or 1e-9
	local xFloat = 1 / x
	local x = math.floor(xFloat + 0.5) -- nearest integer

	if math.abs(1 / x - x) <= tolerance then
		return x
	end

	-- Not an exact 1/X; return the nearest integer anyway.
	return x
end

--[[
	Returns a random point within the bounds of the bounding box.
]]
function Module.getRandomPointInBoundingBox(cframe: CFrame, size: Vector3): Vector3
	local halfX, halfY, halfZ = size.X / 2, size.Y / 2, size.Z / 2
	return cframe:PointToWorldSpace(vect3New(rng:NextNumber(-halfX, halfX), rng:NextNumber(-halfY, halfY), rng:NextNumber(-halfZ, halfZ)))
end

-- in radians
function Module.angleAbs(angle: number): number
	while angle < 0 do
		angle = angle + TAU
	end
	while angle > TAU do
		angle = angle - TAU
	end
	return angle
end

-- in radians
function Module.angleShortest(a0: number, a1: number): number
	local d1 = Module.angleAbs(a1 - a0)
	local d2 = -Module.angleAbs(a0 - a1)
	return abs(d1) > abs(d2) and d2 or d1
end

-- in radians
function Module.lerpAngle(a0: number, a1: number, frac: number): number
	return a0 + Module.angleShortest(a0, a1) * frac
end

function Module.playerVecToAngle(vec: Vector3): number
	return atan2(-vec.Z, vec.X) - rad(90)
end

-- in radians
function Module.playerAngleToVec(angle: number): Vector3
	return vect3New(sin(angle), 0, cos(angle))
end

--dt variable decay function
function Module.friction(val: number, fric: number, deltaTime: number): number
	return (1 / (1 + (deltaTime / fric))) * val
end

function Module.velocityFriction(vel: Vector3, fric: number, deltaTime: number): Vector3
	local speed = vel.Magnitude
	speed = Module.friction(speed, fric, deltaTime)

	if speed < 0.001 then
		return vect3New(0, 0, 0)
	end
	vel = vel.Unit * speed

	return vel
end

-- Removes the Y component of the vector
function Module.flatVec(vec: Vector3): Vector3
	return vect3New(vec.X, 0, vec.Z)
end

--Redirects velocity
function Module.groundAccelerate(wishDir: Vector3, wishSpeed: number, accel: number, velocity: Vector3, dt: number): Vector3
	--Cap velocity
	local speed = velocity.Magnitude
	if speed > wishSpeed then
		velocity = velocity.Unit * wishSpeed
	end

	local wishVel = wishDir * wishSpeed
	local pushDir = wishVel - velocity

	local pushLen = pushDir.Magnitude

	local canPush = accel * dt * wishSpeed

	if canPush > pushLen then
		canPush = pushLen
	end
	if canPush < 0.00001 then
		return velocity
	end
	return velocity + (canPush * pushDir.Unit)
end

function Module.accelerate(wishDir: Vector3, wishSpeed: number, accel: number, velocity: Vector3, dt: number): Vector3
	local speed = velocity.Magnitude

	local currentSpeed = velocity:Dot(wishDir)
	local addSpeed = wishSpeed - currentSpeed

	if addSpeed <= 0 then
		return velocity
	end

	local accelSpeed = accel * dt * wishSpeed
	if accelSpeed > addSpeed then
		accelSpeed = addSpeed
	end

	velocity = velocity + (accelSpeed * wishDir)

	--if we're already going over max speed, don't go any faster than that
	--Or you'll get strafe jumping!
	if speed > wishSpeed and velocity.Magnitude > speed then
		velocity = velocity.Unit * speed
	end
	return velocity
end

function Module.capVelocity(velocity: Vector3, maxSpeed: number): Vector3
	local mag = velocity.Magnitude
	mag = min(mag, maxSpeed)
	if mag > 0.01 then
		return velocity.Unit * mag
	end
	return Vector3.zero
end

function Module.clipVelocity(input: Vector3, normal: Vector3, overbounce: number): Vector3
	local backoff = input:Dot(normal)

	if backoff < 0 then
		backoff = backoff * overbounce
	else
		backoff = backoff / overbounce
	end

	local changex = normal.X * backoff
	local changey = normal.Y * backoff
	local changez = normal.Z * backoff

	return vect3New(input.X - changex, input.Y - changey, input.Z - changez)
end

--Smoothlerp for lua. "Zeno would be proud!"
--Use it in a feedback loop over multiple frames to converge A towards B, in a deltaTime safe way
--eg:  cameraPos = SmoothLerp(cameraPos, target, 0.5, deltaTime)
--Handles numbers and types that implement Lerp like Vector3 and CFrame
function Module.smoothLerp(variableA: any, variableB: any, fraction: number, deltaTime: number): any

	local f = 1.0 - pow(1.0 - fraction, deltaTime)

	if (type(variableA) == "number") then
		return ((1-f) * variableA) + (variableB * f)
	end

	return variableA:Lerp(variableB, f)
end

do
	local SPEED_OF_SOUND = 343 -- meters per second
	local METERS_PER_STUD = 0.28 -- 1 stud is approx 0.28 meter
	
	function Module.getSoundTravelDuration(distanceInStuds: number): number
		local distanceInMeters = distanceInStuds * METERS_PER_STUD
		local duration = distanceInMeters / SPEED_OF_SOUND
		return duration
	end
end

--[[
	Caclulates a CFrame to set on <code>source.Parent</code> so <code>source</code> ends up at the same <code>WorldCFrame</code> as <code>target</code>.
]]
function Module.getAlignedAttachmentsCFrame(source: Attachment, target: Attachment): CFrame
	assert(t.tuple(t.Instance, t.Instance)(source.Parent, target.Parent))
	local targetPart: BasePart = target.Parent :: any
	local targetWorldCFrame = targetPart.CFrame * target.CFrame
	local inverseSourceLocal = source.CFrame:Inverse()
	return targetWorldCFrame * inverseSourceLocal
end

-- Perform a hitbox check. The hitbox will be positioned <code>size.Z / 2</code> in front of <code>origin</code>.
-- <strong>heightCoverage</strong>: Add additional size in the positive Y-direction for height coverage. This will also reposition the hitbox accordingly.
-- <strong>lookAt</strong>: Tilt the hitbox around the X-axis to lookAt
function Module.hitboxCheck(origin: CFrame, size: Vector3, heightCoverage: number?, lookAt: Vector3?, params: OverlapParams?): { BasePart }
	local size = if heightCoverage then size + vect3New(0, heightCoverage, 0) else size
	local finalCFrame = origin * cfNew(0, if heightCoverage then heightCoverage / 2 else 0, -(size.Z / 2))
	if lookAt then
		local direction = (lookAt - origin.Position).Unit
		local angle = asin(direction.Y)
		local tilt = CFrame.Angles(angle, 0, 0)
		finalCFrame *= tilt
	end

	return workspace:GetPartBoundsInBox(finalCFrame, size, params)
end

--[[
	Returns a <code>Vector3</code> that represents the closest surface position to <code>position</code>.
	<strong>shape</strong>: Default shape is 'Box'
	<strong>padding</strong>: Optional padding in studs away from the surface and towards <code>position</code>.
]]
@native
function Module.getClosestSurfacePosition(cframe: CFrame, size: Vector3, position: Vector3, shape: ("Box" | "Sphere" | "Cylinder")?, padding: number?): Vector3
	debug.profilebegin("FunctionUtils::getClosestSurfacePosition")
	-- BALL: Use the smallest axis as the ball’s diameter.
	local shape = shape or "Box"
	local result: Vector3
	if shape == "Box" then
		local localPos = cframe:PointToObjectSpace(position)
		local halfSize = size * 0.5
		local clamped = vect3New(
			clamp(localPos.X, -halfSize.X, halfSize.X),
			clamp(localPos.Y, -halfSize.Y, halfSize.Y),
			clamp(localPos.Z, -halfSize.Z, halfSize.Z)
		)
		result = cframe:PointToWorldSpace(clamped)
	elseif shape == "Sphere" then
		local center = cframe.Position
		local diameter = min(size.X, size.Y, size.Z)
		local radius = diameter * 0.5
		local dir = position - center
		if dir.Magnitude == 0 then
			result = center + cframe.LookVector * radius
		else
			result = center + dir.Unit * radius
		end
	elseif shape == "Cylinder" then
		-- CYLINDER: Dominant (flat) axis is the local X-axis.
		local localPos = cframe:PointToObjectSpace(position)
		local halfLength = size.X * 0.5
		local radius = min(size.Y, size.Z) * 0.5
		local candidate

		if abs(localPos.X) > halfLength then
			-- Case 1: Outside the X-range (caps)
			local clampedX = clamp(localPos.X, -halfLength, halfLength)
			local radial = vect2New(localPos.Y, localPos.Z)
			local clampedRadial = (radial.Magnitude > radius and radial.Unit * radius or radial)
			candidate = vect3New(clampedX, clampedRadial.X, clampedRadial.Y)
		else
			-- Case 2: Within X-range
			local radial = vect2New(localPos.Y, localPos.Z)
			local radialMagnitude = radial.Magnitude
			local radialUnit = radial.Unit
			
			if radialMagnitude > radius then
				candidate = vect3New(localPos.X, radialUnit.X * radius, radialUnit.Y * radius)
			else
				-- Inside cylinder: choose the minimal push out: to the cap or the side.
				local dCap = halfLength - abs(localPos.X)
				local dSide = radius - radialMagnitude
				if dCap < dSide then
					candidate = vect3New(localPos.X >= 0 and halfLength or -halfLength, localPos.Y, localPos.Z)
				else
					if radialMagnitude == 0 then
						candidate = vect3New(localPos.X, radius, 0)
					else
						candidate = vect3New(localPos.X, radialUnit.X * radius, radialUnit.Y * radius)
					end
				end
			end
		end

		result = cframe:PointToWorldSpace(candidate)
	else
		error(`don't know how to handle shape: {shape}`, 2)
	end
	
	if padding and padding ~= 0 then
		local direction = (position - result)
		if direction.Magnitude > 0 then
			result += direction.Unit * padding
		end
	end
	
	debug.profileend()
	return result
end

--[[
	Uses <code>Enum.PartType</code> of <code>part</code>.
	Does not support wedges.
]]
function Module.getClosestSurfacePositionOn(part: BasePart, position: Vector3)
	debug.profilebegin("FunctionUtils::getClosestSurfacePositionOn")
	local shape = if part:IsA("Part") then part.Shape else nil
	local result: Vector3
	if shape == Enum.PartType.Ball then
		result = Module.getClosestSurfacePosition(part.CFrame, part.Size, position, "Sphere")
	elseif shape == Enum.PartType.Cylinder then
		result = Module.getClosestSurfacePosition(part.CFrame, part.Size, position, "Cylinder")
	else
		result = Module.getClosestSurfacePosition(part.CFrame, part.Size, position, "Box")
	end
	debug.profileend()
	return result
end

function Module.getRandomPointOnSphereSurface(center: Vector3, radius: number): Vector3
	local u = rng:NextNumber()
	local v = rng:NextNumber()
	local theta = u * TAU
	local phi = acos(2 * v - 1)

	local x = radius * sin(phi) * cos(theta)
	local y = radius * sin(phi) * sin(theta)
	local z = radius * cos(phi)

	return center + vect3New(x, y, z)
end

-- Returns a point on a hemisphere's surface given a center, radius, and min/max from the origin.
-- <strong>radiusRange</strong>: Distance from the sphere's center for point. Must not exceed the radius. Default is (1, 1).
-- <strong>partial</strong>: Describes the partial sphere. 1 is a full sphere. Default is 0.5
function Module.getRandomPointOnPartialSphereSurface(center: Vector3, radiusRange: NumberRange?, partial: number?): Vector3
	local partial = partial or 0.5
	local radiusRange = radiusRange or NumberRange.new(1)
	local minRadius = radiusRange.Min
	local maxRadius = radiusRange.Max

	-- Random radius between minRadius and maxRadius.
	local r = rng:NextNumber() * (maxRadius - minRadius) + minRadius

	-- Compute the maximum polar angle allowed.
	-- For a full sphere (partial = 1), maxTheta is π.
	-- For an upper half-sphere (partial = 0.5), maxTheta is π/2.
	local maxTheta = PI * partial

	-- To ensure a uniform distribution over the spherical cap,
	-- pick cos(theta) uniformly in [cos(maxTheta), 1].
	local cosTheta = rng:NextNumber() * (1 - cos(maxTheta)) + cos(maxTheta)
	local theta = acos(cosTheta)

	-- φ (phi) is uniformly distributed from 0 to 2π.
	local phi = rng:NextNumber() * TAU

	-- Convert spherical coordinates (r, theta, phi) to Cartesian coordinates.
	local x = r * sin(theta) * cos(phi)
	local y = r * cos(theta)
	local z = r * sin(theta) * sin(phi)

	-- Return the final position by offsetting with the center.
	return center + vect3New(x, y, z)
end

-- <strong>up</strong>: Vector3.yAxis is the default.
function Module.getRightVector(look: Vector3, up: Vector3?): Vector3
	local up = up or Vector3.yAxis
	return look:Cross(up).Unit
end

-- Returns a closure that returns an incremented ID each time it is called.
-- The ID can reset back to 0 if given <code>resetAfter</code>
function Module.getIdGenerator(increment: number?, resetAfter: number?): (() -> (number))
	local increment = increment or 1
	local id = 0
	return function()
		if resetAfter and id >= resetAfter then
			id = 0
		end
		id += increment
		return id
	end
end

-- Stacks the <strong>increaseAmount</strong> linearly.
function Module.linearStacking(increaseAmount: number, stackCount: number): number
	return increaseAmount * stackCount
end

-- Stacks the <strong>increaseAmount</strong> exponentially.
-- This will cause rapid progression of the <strong>increaseAmount</strong> at higher stack counts.
function Module.exponentialStacking(increaseAmount: number, stackCount: number): number
	return (increaseAmount)^stackCount
end

-- Stacks the <strong>increaseAmount</strong> hyperbolically.
-- This is good for something that increases by, say, '25%', but you don't want to reach 100% after 4 stacks.
-- E.g. 'Reduce damage by 25% per stack', but you don't reach 100% damage reduction only at 4 stack count.
function Module.hyperbolicStacking(increaseAmount: number, stackCount: number): number
	return (1 - 1/(1 + increaseAmount * stackCount))
end

-- SweetSpot dropoff is 100% dmg from center to half radius, then 25% from half radius to edge.
function Module.sweetSpotDropoff(distanceFromOriginInStuds: number, radiusInStuds: number): number
	-- 100% damage from center to half radius, and then 25% damage from half radius to radius edge
	if distanceFromOriginInStuds > radiusInStuds then
		return 0
	end
	return if distanceFromOriginInStuds <= radiusInStuds / 2 then 1 else 0.25
end

-- Returns a damage multiplier between 0-1.
function Module.logarithmicDropoff(distanceFromOriginInStuds: number, radiusInStuds: number): number
	if distanceFromOriginInStuds > radiusInStuds then
		return 0
	end
	local normalizedDistance = distanceFromOriginInStuds / radiusInStuds
	return clamp(1 / log(radiusInStuds + 1) * log(radiusInStuds - (radiusInStuds * normalizedDistance) + 1), 0, 1)
end

-- Returns a damage multiplier between 0-1.
function Module.linearDropoff(distanceFromOriginInStuds: number, radiusInStuds: number): number
	if distanceFromOriginInStuds > radiusInStuds then
		return 0
	end
	return clamp(1 - (distanceFromOriginInStuds / radiusInStuds), 0, 1)
end

-- Returns a damage multiplier between 0-1.
function Module.exponentialDropoff(distanceFromOriginInStuds: number, radiusInStuds: number, attenuationFactor: number?): number
	local ATTENUATION_FACTOR = 0.2 -- looks best on desmos (a reflection of log dropoff)
	-- only good for small distances (less than 20 studs), larger distances require smaller factor!
	
	-- the larger the attenuation factor, the faster the drop off!
	if distanceFromOriginInStuds > radiusInStuds then
		return 0
	end
	local linearFactor = (radiusInStuds - distanceFromOriginInStuds) / radiusInStuds
	local expFactor = math.exp(-distanceFromOriginInStuds * (attenuationFactor or ATTENUATION_FACTOR))
	return clamp(linearFactor * expFactor, 0, 1)
end

-- Clamps the Vector3 values by the specified ranges. Does nothing if no range is provided.
function Module.clampVector3(v: Vector3, xClamp: NumberRange?, yClamp: NumberRange?, zClamp: NumberRange?): Vector3
	return vect3New(
		if xClamp then clamp(v.X, xClamp.Min, xClamp.Max) else v.X,
		if yClamp then clamp(v.Y, yClamp.Min, yClamp.Max) else v.Y,
		if zClamp then clamp(v.Z, zClamp.Min, zClamp.Max) else v.Z
	)
end

-- Calculates the distance a particle would travel from an emitter.
function Module.getParticleDistanceTravelled(drag: number, speed: number, lifetime: number): number
	if drag == 0 then
		return speed * lifetime
	end

	local ln2 = log(2)
	return (speed / (drag * ln2)) * (1 - 2 ^ (-drag * lifetime))
end

-- Calculates what a particle's speed should be in order to reach <code>distance</code>.
function Module.getParticleSpeedToCoverDistance(distance: number, drag: number, lifetime: number)
	if lifetime <= 0 or distance <= 0 then
		return 0
	end

	-- If there's no drag, then the velocity doesn't decay,
	-- and we just do distance = speed * lifetime
	if drag == 0 then
		return distance / lifetime
	end

	local ln2 = log(2)
	local factor = 1 - 2 ^ (-drag * lifetime)

	-- Avoid dividing by a tiny number (which would blow up speed).
	if abs(factor) < 1e-9 then
		-- Means we basically get almost zero distance from decay,
		-- so to travel a nonzero distance would require a huge speed.
		return HUGE
	end

	-- Solve for speed
	local speed = distance * (drag * ln2) / factor
	return speed
end

-- Returns the signed difference from angleA to angleB in the range (-π, π].
function Module.angleDiffSigned(angleA: number, angleB: number)
	local diff = (angleB - angleA) % TAU
	if diff > PI then
		diff = diff - TAU
	end
	return diff
end

-- Clamps <strong>toClamp</strong> within <strong>limitOrigin + lowerLimit</strong> and <strong>limitOrigin + upperLimit</strong>
-- and maintains continuous angle motion (no awkward flips to negative angles).
-- <strong>limitOrigin</strong>: 0 by default.
-- All values must be in radians.
function Module.clampAngle(toClamp: number, lowerLimit, upperLimitDeg: number, limitOrigin: number?): number
	local limitOrigin = limitOrigin or 0
	local diff = Module.angleDiffSigned(limitOrigin, toClamp)
	local clampedDiff = clamp(diff, lowerLimit, upperLimitDeg)
	return (limitOrigin + clampedDiff)
end

--[[
	Returns a boolean signifying if x is within the given range.
	Default mode is include.
]]
function Module.withinRange(
	x: number,
	min: number,
	max: number,
	mode: ("include" | "exclude" | "excludeMax" | "excludeMin")?
): boolean
	local mode = mode or "include"
	if mode == "include" then
		return x >= min and x <= max
	elseif mode == "excludeMax" then
		return x >= min and x < max
	elseif mode == "excludeMin" then
		return x > min and x <= max
	elseif mode == "exclude" then
		return x > min and x < max
	end
	error(`invalid mode '{mode}'`, 2)
end

function Module.lerp(start: any, goal: any, alpha: number): number
	return start + (goal - start) * alpha
end

function Module.getAlpha(start: any, goal: any, current: any): number
	return (current - start) / (goal - start)
end

-- Returns x if less than or equal to max and greater than or equal to min (1 by default).
-- Returns min if x is greater than max. Returns max if x is less than min.
function Module.loopNumber(x: number, max: number, min: number?): number
	local min = min or 1
	return if x > max then min elseif x < min then max else x
end

function Module.isNaN(num: number): boolean
	return num ~= num
end

function Module.isFinite(num: number): boolean
	return num > -HUGE and num < HUGE
end

--[[
	Rounds a number to the nearest multiple of a given base (5s, 10s, 100s, 1000s, etc).
	<strong>direction</strong>: Default is "nearest"
]]
function Module.roundToMultiple(number: number, multiple: number, direction: ("nearest" | "up" | "down")?) : number
	assert(typeof(number) == "number", "Expected number")
	assert(typeof(multiple) == "number" and multiple > 0, "Expected multiple > 0")

	local direction = direction or "nearest"

	if direction == "nearest" then
		return math.floor((number / multiple) + 0.5) * multiple
	elseif direction == "up" then
		return math.ceil(number / multiple) * multiple
	elseif direction == "down" then
		return math.floor(number / multiple) * multiple
	else
		error(`Invalid direction: {direction}`, 2)
	end
end

-- Rounds to to the closest integer, or including decimal places.
function Module.round(number: number, decimalPlaces: number?): number
	if decimalPlaces and (typeof(decimalPlaces) ~= "number" or decimalPlaces <= 0) then
		error("Invalid decimalPlaces: must be a positive number or zero.", 2)
	end
	assert(t.number(number))

	local factor = if decimalPlaces then 10^decimalPlaces else 1

	return math.floor(number * factor + 0.5) / factor
end

function Module.roundUp(number: number, precision: number): number
	return math.ceil(number/precision) * precision
end

function Module.roundDown(number: number, precision: number): number
	return math.floor(number/precision) * precision
end

function Module.map(num: number, min0: number, max0: number, min1: number, max1: number): number
	assert(max0 > min0, "Invalid Range: Range must be greater than zero")

	return (((num - min0)*(max1 - min1)) / (max0 - min0)) + min1
end

-- Percent difference between two positive numbers greater than 0. Percentage difference is usually calculated 
-- when you want to know the difference in percentage between two numbers. The order of the numbers does not matter 
-- as we are simply dividing the difference between two numbers by the average of the two numbers.
function Module.percentDifference(v1: number, v2: number): number
	assert(v1 and v1 > 0, "Invalid v1 passed. Expected number greater than 0")
	assert(v2 and v2 > 0, "Invalid v2 passed. Expected number greater than 0")
	return abs(v1 - v2)/((v1+v2)/2)*100
end

--Quantifies the change from one number to another and expresses the change as an increase or decrease.
--Going from 10 apples to 20 apples is a 100% increase (change) in the number of apples.
--Vice verse would be 20 to 10 therefore 50% decrease. Negative numbers indicate a decrease and positive increase.
function Module.percentChange(originalValue: number, newValue: number): number
	return (newValue - originalValue)/abs(originalValue)*100
end

--[[
	Returns a float between 0-100 that describes the progress to <code>goal</code>.
]]
function Module.getProgress(current: number, goal: number): number
	return (current/goal)*100
end

function Module.getFpsScale(deltaTime: number, targetFps: number)
	return targetFps / (1 / deltaTime)
end

-- Returns a bounding-box that can be aligned with the world-axes.
-- <strong>orientation</strong>: The reference orientation for calculating the bounding box.
-- If not specified, this bounding box will be aligned with the global axes, basically creating a 'static' bounding box
-- that resizes to fit the part based on its orientation.
function Module.getPartExtentsSize(part: BasePart, orientation: CFrame?): Vector3
	local orientation = orientation or CFrame.identity
	local partCFrame: CFrame = part.CFrame

	partCFrame = orientation:ToObjectSpace(partCFrame)

	local size: Vector3 = part.Size
	local sx: number, sy: number, sz: number = size.X, size.Y, size.Z

	local x: number, y: number, z: number,
	R00: number, R01: number, R02: number,
	R10: number, R11: number, R12: number,
	R20: number, R21: number, R22: number = partCFrame:GetComponents()

	local wsx: number = 0.5 * (abs(R00) * sx + abs(R01) * sy + abs(R02) * sz)
	local wsy: number = 0.5 * (abs(R10) * sx + abs(R11) * sy + abs(R12) * sz)
	local wsz: number = 0.5 * (abs(R20) * sx + abs(R21) * sy + abs(R22) * sz)

	return vect3New(x + wsx, y + wsy, z + wsz) - vect3New(x - wsx, y - wsy, z - wsz)
end

--[[
	Mimics <code>:GetExtentsSize()</code> but with filtering behavior.
	Alias for <code>select(2, getAxisAlignedBoudningBox(target, params))</code>.
]]
@native
function Module.getExtentsSize(target: any, params: RaycastParams?): Vector3
	-- Reuse our AABB implementation (supports RaycastParams filtering and
	-- respects the implicit non-CanQuery exclusion when params is provided).
	local _cf, worldAlignedExtents = Module.getAxisAlignedBoundingBox(target, params)
	return worldAlignedExtents
end

-- Grabs the world bounding box (a bounding box that is rotationally-static but resizes to fit the model).
-- For parts, use <code>getPartExtentsSize()</code> without an orientation.
function Module.getWorldBoundingBox(model: Model)
	debug.profilebegin("Functionutils::getWorldBoundingBox")
	local cf, size = model:GetBoundingBox()
	-- The bounding box from GetBoundingBox() is oriented to the model’s axes, 
	-- not the world’s. We need to figure out the axis-aligned bounding box in world space.

	-- Compute the 8 corners of that oriented bounding box
	local halfSize = size * 0.5
	local corners = {
		vect3New(-halfSize.X, -halfSize.Y, -halfSize.Z),
		vect3New(-halfSize.X, -halfSize.Y,  halfSize.Z),
		vect3New(-halfSize.X,  halfSize.Y, -halfSize.Z),
		vect3New(-halfSize.X,  halfSize.Y,  halfSize.Z),
		vect3New( halfSize.X, -halfSize.Y, -halfSize.Z),
		vect3New( halfSize.X, -halfSize.Y,  halfSize.Z),
		vect3New( halfSize.X,  halfSize.Y, -halfSize.Z),
		vect3New( halfSize.X,  halfSize.Y,  halfSize.Z),
	}

	-- Transform them into world space
	local minX, minY, minZ = HUGE, HUGE, HUGE
	local maxX, maxY, maxZ = -HUGE, -HUGE, -HUGE

	for _, corner in ipairs(corners) do
		local worldPos = cf:PointToWorldSpace(corner)
		if worldPos.X < minX then minX = worldPos.X end
		if worldPos.Y < minY then minY = worldPos.Y end
		if worldPos.Z < minZ then minZ = worldPos.Z end

		if worldPos.X > maxX then maxX = worldPos.X end
		if worldPos.Y > maxY then maxY = worldPos.Y end
		if worldPos.Z > maxZ then maxZ = worldPos.Z end
	end

	-- Compute final axis-aligned center & size
	local alignedSize = vect3New(maxX - minX, maxY - minY, maxZ - minZ)
	local alignedCenter = vect3New(
		0.5 * (minX + maxX),
		0.5 * (minY + maxY),
		0.5 * (minZ + maxZ)
	)
	
	debug.profileend()
	return alignedCenter, alignedSize
end

do
	local function defaultFilter(instance: Instance): boolean
		return instance:IsA("BasePart")
	end
	
	--[[
		Gets the oriented bounding box of the part/model. All parts are included by default.
		<strong>params</strong>: Optionally filter what instances are used to calculate the extents of the bounding box.
		Including a blank raycast parameter will automatically exclude all non-CanQuery parts!
		SUPPORTED:
		<strong>RespectCanCollide</strong>: Include only collideable parts.
		<strong>FilterDescendantsInstances</strong>: Include/exclude based on <strong>FilterType</strong>. An empty table will be ignored.
		NOT SUPPORTED YET:
		<strong>CollisionGroup</strong>
	]]
	@native
	function Module.getOrientedBoundingBox(target: Model | BasePart, params: RaycastParams?): (CFrame, Vector3)
		debug.profilebegin("FunctionUtils::getOrientedBoundingBox")
		local filter: (Instance) -> boolean
		if params then
			local roots = params.FilterDescendantsInstances or {}
			local filterType = params.FilterType or Enum.RaycastFilterType.Exclude
			local respectCanCollide = params.RespectCanCollide
			local rootCount = #roots

			filter = function(part)
				if not part:IsA("BasePart") then
					return false
				end
				if not part.CanQuery then
					return false
				end
				if respectCanCollide and not part.CanCollide then
					return false
				end

				if rootCount > 0 then
					if filterType == Enum.RaycastFilterType.Exclude then
						for _, r in ipairs(roots) do
							if part:IsDescendantOf(r) then
								return false
							end
						end
					else
						for _, r in ipairs(roots) do
							if part:IsDescendantOf(r) then
								return true
							end
						end
						return false
					end
				end

				return true
			end
		else
			filter = defaultFilter
		end

		-- collect all valid BaseParts
		local parts: { BasePart } = {}
		if target:IsA("Model") then
			local i = 0
			for _, desc: any in ipairs(target:GetDescendants()) do
				if filter(desc) then
					i += 1
					parts[i] = desc
				end
			end
		elseif target:IsA("BasePart") then
			if filter(target) then
				parts[1] = target
			end
		end

		if #parts == 0 then
			-- Mirror Roblox's behavior for empty model :GetBoundingBox
			-- Choose an orientation that is stable/unsurprising.
			local basis: CFrame
			if target:IsA("BasePart") then
				-- Use the part's rotation (translation zeroed)
				local cf = target:GetPivot()
				basis = CFrame.fromMatrix(
					Vector3.zero,
					cf.RightVector,
					cf.UpVector,
					cf.LookVector
				)
			else
				-- Uses its pivot orientation if any parts were filtered out,
				-- else identity if the model is empty.
				local pivot = target:GetPivot()
				basis = CFrame.fromMatrix(
					Vector3.zero,
					pivot.RightVector,
					pivot.UpVector,
					pivot.LookVector
				)
			end

			return basis, Vector3.zero
		end


		--- 3) pick the orientation CFrame
		local orientCFrame: CFrame
		if target:IsA("BasePart") then
			-- use the part’s CFrame but zero out translation
			local cf = target:GetPivot()
			orientCFrame = CFrame.fromMatrix(
				Vector3.zero,
				cf.RightVector,
				cf.UpVector,
				cf.LookVector
			)
		else
			-- model: use its PrimaryPart's orientation
			local pivot = target:GetPivot()
			orientCFrame = CFrame.fromMatrix(
				Vector3.zero,
				pivot.RightVector,
				pivot.UpVector,
				pivot.LookVector
			)
		end

		--- 4) accumulate min/max *in the target’s local space*
		local mMin, mMax, mAbs = min, max, abs

		local minX, minY, minZ = HUGE, HUGE, HUGE
		local maxX, maxY, maxZ = -HUGE, -HUGE, -HUGE

		-- cache the local‐space axes
		local localRight, localUp, localLook = orientCFrame.RightVector, orientCFrame.UpVector, orientCFrame.LookVector

		for _, part in ipairs(parts) do
			-- each part’s half‐size
			local halfSize = part.Size * 0.5
			-- world‐space axes of the part
			local right, up, left = part.CFrame.RightVector, part.CFrame.UpVector, part.CFrame.LookVector

			-- projected extents along each *local* axis
			local ex = halfSize.X * mAbs(right:Dot(localRight))
				+ halfSize.Y * mAbs(up:Dot(localRight))
				+ halfSize.Z * mAbs(left:Dot(localRight))

			local ey = halfSize.X * mAbs(right:Dot(localUp))
				+ halfSize.Y * mAbs(up:Dot(localUp))
				+ halfSize.Z * mAbs(left:Dot(localUp))

			local ez = halfSize.X * mAbs(right:Dot(localLook))
				+ halfSize.Y * mAbs(up:Dot(localLook))
				+ halfSize.Z * mAbs(left:Dot(localLook))

			-- center of the part in local coords
			local localPos = orientCFrame:PointToObjectSpace(part.CFrame.Position)

			-- update mins/maxs in local space
			minX = mMin(minX, localPos.X - ex)
			maxX = mMax(maxX, localPos.X + ex)
			minY = mMin(minY, localPos.Y - ey)
			maxY = mMax(maxY, localPos.Y + ey)
			minZ = mMin(minZ, localPos.Z - ez)
			maxZ = mMax(maxZ, localPos.Z + ez)
		end

		--- 5) compute final center & extents, and reproject center back into world
		local centerLocal  = vect3New(
			(minX + maxX) * 0.5,
			(minY + maxY) * 0.5,
			(minZ + maxZ) * 0.5
		)
		local extentsLocal = vect3New(
			(maxX - minX),
			(maxY - minY),
			(maxZ - minZ)
		)

		-- world-space CFrame of the oriented box
		local worldCenterCFrame = orientCFrame * cfNew(centerLocal)
		
		debug.profileend()
		return worldCenterCFrame, extentsLocal
	end
	
	@native
	--[[
		Gets the world axis-aligned bounding box of the part/model. All parts are included by default.
		<strong>params</strong>: Optionally filter what instances are used to calculate the extents of the bounding box.
		Including a blank raycast parameter will automatically exclude all non-CanQuery parts!
		SUPPORTED:
		<strong>RespectCanCollide</strong>: Include only collideable parts.
		<strong>FilterDescendantsInstances</strong>: Include/exclude based on <strong>FilterType</strong>. An empty table will be ignored.
		NOT SUPPORTED YET:
		<strong>CollisionGroup</strong>
	]] 
	function Module.getAxisAlignedBoundingBox(target: any, params: RaycastParams?): (CFrame, Vector3)
		debug.profilebegin("FunctionUtils::getAxisAlignedBoundingBox")
		-- build filter once
		local filter: (any) -> (boolean)
		if params then
			local roots = params.FilterDescendantsInstances
			local filterType = params.FilterType or Enum.RaycastFilterType.Exclude
			local respectCanCollide = params.RespectCanCollide
			local rootCount = #roots

			filter = function(part)
				if not part:IsA("BasePart") then
					return false
				end
				if not part.CanQuery then
					return false
				end
				if respectCanCollide and not part.CanCollide then
					return false
				end

				if rootCount > 0 then
					if filterType == Enum.RaycastFilterType.Exclude then
						for _, root in ipairs(roots) do
							if part:IsDescendantOf(root) then
								return false
							end
						end
					else
						for _, root in ipairs(roots) do
							if part:IsDescendantOf(root) then
								return true
							end
						end
						return false
					end
				end

				return true
			end
		else
			filter = defaultFilter
		end

		-- collect parts
		local parts: { BasePart } = {}
		if target:IsA("Model") then
			local i = 0
			for _, desc in ipairs(target:GetDescendants()) do
				if filter(desc) then
					i += 1
					parts[i] = desc
				end
			end
		elseif target:IsA("BasePart") then
			if filter(target) then
				parts[1] = target
			end
		end

		if #parts == 0 then
			-- Mirror Roblox's GetBoundingBox on empty model: neutral CFrame + zero size.
			-- For a model, prefer its pivot as the center; for a part, use its CFrame.
			local centerCF: CFrame
			if typeof(target) == "Instance" then
				if target:IsA("Model") then
					centerCF = target:GetPivot()
				elseif target:IsA("BasePart") then
					centerCF = target.CFrame
				else
					centerCF = CFrame.identity
				end
			else
				centerCF = CFrame.identity
			end
			return centerCF, Vector3.zero
		end

		-- setup locals for math
		local mMin, mMax, mAbs = min, max, abs
		local minX, minY, minZ = HUGE, HUGE, HUGE
		local maxX, maxY, maxZ = -HUGE, -HUGE, -HUGE

		-- single-pass AABB per part
		for _, part in ipairs(parts) do
			local cf = part.CFrame
			local pos = cf.Position
			local halfSize = part.Size * 0.5
			local right, up, left = cf.RightVector, cf.UpVector, cf.LookVector

			local xExtent = halfSize.X * mAbs(right.X) 
				+ halfSize.Y * mAbs(up.X) 
				+ halfSize.Z * mAbs(left.X)
			local yExtent = halfSize.X * mAbs(right.Y) 
				+ halfSize.Y * mAbs(up.Y) 
				+ halfSize.Z * mAbs(left.Y)
			local zExtent = halfSize.X * mAbs(right.Z) 
				+ halfSize.Y * mAbs(up.Z) 
				+ halfSize.Z * mAbs(left.Z)

			minX = mMin(minX, pos.X - xExtent)
			maxX = mMax(maxX, pos.X + xExtent)
			minY = mMin(minY, pos.Y - yExtent)
			maxY = mMax(maxY, pos.Y + yExtent)
			minZ = mMin(minZ, pos.Z - zExtent)
			maxZ = mMax(maxZ, pos.Z + zExtent)
		end

		-- 6) build result
		local center  = vect3New((minX + maxX) * 0.5,
			(minY + maxY) * 0.5,
			(minZ + maxZ) * 0.5)
		local extents = vect3New(maxX - minX,
			maxY - minY,
			maxZ - minZ)
		
		debug.profileend()
		return cfNew(center), extents
	end
end

-- Grabs the bounding box of a part or model.
-- For a rotationally-static bounding box, use <code>getPartExtentsSize()</code> or <code>getWorldBoundingBox()</code>.
function Module.getBoundingBox(instance: BasePart | Model): (CFrame, Vector3)
	if instance:IsA("BasePart") then
		return instance.CFrame, instance.Size
	elseif instance:IsA("Model") then
		return instance:GetBoundingBox()
	end
	error("Invalid instance", 2)
end

-- Calculates the bounding box that perfectly encapsulates the part/model aligned with the camera's axes.
-- <strong>camera</strong>: Defaults to workspace.CurrentCamera if not provided.
function Module.getCameraAlignedBoundingBox(instance: BasePart | Model, camera: Camera?): (CFrame, Vector3)
	debug.profilebegin("FunctionUtils::getCameraAlignedBoundingBox")
	local camera = camera or workspace.CurrentCamera
	if not camera then
		return CFrame.identity, Vector3.zero
	end

	local baseCFrame, size do
		if instance:IsA("BasePart") then
			baseCFrame, size = instance.CFrame, instance.Size
		elseif instance:IsA("Model") then
			baseCFrame, size = instance:GetBoundingBox()
		else
			return CFrame.identity, Vector3.zero
		end
	end

	local halfSize = size * 0.5
	local corners = {
		vect3New(-halfSize.X, -halfSize.Y, -halfSize.Z),
		vect3New(-halfSize.X, -halfSize.Y,  halfSize.Z),
		vect3New(-halfSize.X,  halfSize.Y, -halfSize.Z),
		vect3New(-halfSize.X,  halfSize.Y,  halfSize.Z),
		vect3New( halfSize.X, -halfSize.Y, -halfSize.Z),
		vect3New( halfSize.X, -halfSize.Y,  halfSize.Z),
		vect3New( halfSize.X,  halfSize.Y, -halfSize.Z),
		vect3New( halfSize.X,  halfSize.Y,  halfSize.Z),
	}

	local camCF = camera.CFrame
	local minX, minY, minZ = HUGE, HUGE, HUGE
	local maxX, maxY, maxZ = -HUGE, -HUGE, -HUGE

	for _, cornerLocal in ipairs(corners) do
		local cornerWorld = baseCFrame:PointToWorldSpace(cornerLocal)
		local cornerCam   = camCF:PointToObjectSpace(cornerWorld)

		if cornerCam.X < minX then minX = cornerCam.X end
		if cornerCam.Y < minY then minY = cornerCam.Y end
		if cornerCam.Z < minZ then minZ = cornerCam.Z end

		if cornerCam.X > maxX then maxX = cornerCam.X end
		if cornerCam.Y > maxY then maxY = cornerCam.Y end
		if cornerCam.Z > maxZ then maxZ = cornerCam.Z end
	end

	local minCam = vect3New(minX, minY, minZ)
	local maxCam = vect3New(maxX, maxY, maxZ)
	local centerCam = (minCam + maxCam) * 0.5
	local extentCam = maxCam - minCam

	local centerWorld = camCF:PointToWorldSpace(centerCam)
	local rotationOnly = camCF - camCF.Position

	local boundingBoxCF = rotationOnly + centerWorld
	
	debug.profileend()
	return boundingBoxCF, extentCam
end

-- Returns the world position that represents the anchor point for the BillboardGui.
-- This calculation accurately takes into account the billboard's extents and studs offset properties.
function Module.getBillboardWorldPosition(billboardGui: BillboardGui, camera: Camera?): Vector3?
	local adornee: Attachment | BasePart | Model = (billboardGui.Adornee or billboardGui.Parent) :: any
	if not adornee then
		return
	end
	debug.profilebegin("FunctionUtils::getBillboardWorldPosition")

	local adorneeCFrame
	if adornee:IsA("Attachment") then
		adorneeCFrame = adornee.WorldCFrame
	elseif adornee:IsA("BasePart") then
		adorneeCFrame = adornee.CFrame
	elseif adornee:IsA("Model") then
		-- For a model, Roblox uses bounding-box CFrame instead of :GetPivot()
		local cf, _ = adornee:GetBoundingBox()
		adorneeCFrame = cf
	else
		debug.profileend()
		return
	end

	local camera = camera or workspace.CurrentCamera
	if not camera then
		debug.profileend()
		return
	end

	local finalPos = adorneeCFrame.Position

	-- 'StudsOffsetWorldSpace' is a bit misleading because the the offset is applied based on the adornee's axes and not the world axes.
	-- But technically the Vector offset is in world space.
	finalPos = finalPos + adorneeCFrame:VectorToWorldSpace(billboardGui.StudsOffsetWorldSpace)

	-- Offset based on camera's orientation (excluding position since the camera is not the adornee).
	local camCFrame = camera.CFrame
	local camRot = camCFrame - camCFrame.Position
	local studsOffset = billboardGui.StudsOffset
	local studsOffsetWorld = camRot:VectorToWorldSpace(studsOffset)
	finalPos = finalPos + studsOffsetWorld

	-- Extents properties are ignored for attachments!
	if not adornee:IsA("Attachment") then
		-- EXTENTS OFFSET WORLD SPACE --
		if billboardGui.ExtentsOffsetWorldSpace ~= Vector3.zero then
			local offset = billboardGui.ExtentsOffsetWorldSpace

			-- Get the bounding-box size in world axes
			local cframe, sizeWS = Module.getBoundingBox(adornee)
			local halfSizeWS = sizeWS * 0.5

			-- Multiply per-axis
			local offset = vect3New(
				halfSizeWS.X * offset.X,
				halfSizeWS.Y * offset.Y,
				halfSizeWS.Z * offset.Z
			)

			offset = cframe:VectorToWorldSpace(offset)
			finalPos += offset
		end
		
		-- EXTENTS OFFSET --
		if billboardGui.ExtentsOffset ~= Vector3.zero then
			local offset = billboardGui.ExtentsOffset

			-- Get camera-aligned bounding box size
			local _, sizeCam = Module.getCameraAlignedBoundingBox(adornee, camera)
			local halfSizeCam = sizeCam * 0.5

			-- Scale the offset by half the camera bounding box
			local offsetCamSpace = vect3New(
				halfSizeCam.X * offset.X,
				halfSizeCam.Y * offset.Y,
				halfSizeCam.Z * offset.Z
			)

			-- Rotate from camera space to world space
			-- We'll get pure rotation from the camera by subtracting translation:
			local camCFrame = camera.CFrame
			local camRotOnly = camCFrame - camCFrame.Position

			offset = camRotOnly:VectorToWorldSpace(offsetCamSpace)
			finalPos += offset
		end
	end

	debug.profileend()
	return finalPos
end

-- Given a ground position and model, this returns what the model should be :PivotTo() for a flush ground position.
function Module.getPivotFlushWithGround(groundPoint: CFrame, model: Model): CFrame
	local pivot = model:GetPivot()
	local center, size = model:GetBoundingBox()

	local bottomWorld = vect3New(
		center.X,
		center.Y - size.Y / 2,
		center.Z
	)

	local offset = pivot:PointToObjectSpace(bottomWorld)

	return groundPoint * cfNew(-offset)
end

--[[
	Casts a ray downward from the given origin to find the ground surface.
	- origin: Starting world position (Vector3) for the ray.
	- rayDistance: Optional maximum ray distance (default 500).
	- ignoreList: Optional array of Instances to ignore in the raycast.
	
	Returns a CFrame located at the hit position and aligned with the surface normal.
	If no hit occurs, returns a CFrame at the original origin (facing upward)
]]
function Module.getGroundPointFromVector3(origin: Vector3, rayDistance: number?, ignoreList: {Instance}?): CFrame
	assert(origin and t.Vector3(origin))
	local distance = rayDistance or 500
	
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList or {}

	local rayResult = workspace:Raycast(origin, vect3New(0, -distance, 0), params)
	
	if rayResult then
		-- Align CFrame with the hit surface normal
		local hitPos = rayResult.Position
		local normal = rayResult.Normal

		-- Create a right vector perpendicular to the normal for orientation
		local up = normal
		local forward = vect3New(0, 0, 1)
		if math.abs(up:Dot(forward)) > 0.99 then
			forward = vect3New(1, 0, 0)
		end

		local right = up:Cross(forward).Unit
		local back = right:Cross(up).Unit

		local rotation = CFrame.fromMatrix(hitPos, right, up, back)
		return rotation
	else
		-- No ground hit, return upright CFrame at original position
		return CFrame.new(origin)
	end
end

--[[
	Casts a ray downward from the given origin CFrame to find the ground surface.
	- originCFrame: The starting world-space CFrame (includes position and orientation).
	- rayDistance: Optional maximum ray distance (default 500).
	- params: Optional params for the raycast.

	Returns a CFrame located at the hit position and aligned with the surface normal.
	If no hit occurs, returns the original originCFrame.
]]
function Module.getGroundPointFromCFrame(originCFrame: CFrame, rayDistance: number?, params: RaycastParams?): CFrame
	local distance = rayDistance or 500
	local params = params or RaycastParams.new()

	-- Ray origin and direction
	local origin = originCFrame.Position
	local direction = -originCFrame.UpVector * distance

	-- Perform raycast downward relative to orientation
	local rayResult = workspace:Raycast(origin, direction, params)

	if rayResult then
		local hitPos = rayResult.Position
		local normal = rayResult.Normal

		-- Align CFrame with hit surface normal
		local up = normal
		local forward = originCFrame.LookVector

		-- Ensure forward isn't parallel to up (prevents gimbal lock)
		if math.abs(up:Dot(forward)) > 0.99 then
			forward = originCFrame.RightVector
		end

		local right = up:Cross(forward).Unit
		local adjustedForward = right:Cross(up).Unit

		return CFrame.fromMatrix(hitPos, right, up, adjustedForward)
	else
		-- No ground hit, return the original CFrame unchanged
		return originCFrame
	end
end

-- Resizes the model via <code>:ScaleTo()</code> to ensure it's scaled to the given spherical volume.
function Module.resizeModelToFitRadius(model: Model, radius: number)
	assert(typeof(radius) == "number" and radius > 0, "Invalid radius")

	local pivotCFrame, size = model:GetBoundingBox()
	
	local currentRadius = size.Magnitude * 0.5
	if currentRadius <= 0 then return end

	local currentScale = model:GetScale()
	local desiredScale = (radius / currentRadius) * currentScale

	model:ScaleTo(desiredScale)
end

-- Returns the central bottom point of the model's bounding box (includes orientation)
function Module.getBottomPositionOfModel(model: Model): Vector3
	local boundingBox, size = model:GetBoundingBox()
	return (boundingBox * cfNew(0, -size.Y / 2, 0)).Position
end

-- A write-safe alternative to <code>TweenService:GetValue()</code> (which is not safe to call in parallel).
function Module.getTweenValue(alpha: number, easingStyle: Enum.EasingStyle, easingDirection: Enum.EasingDirection): number
	local easingStyleFunc = _easingStyle[easingStyle.Name]
	local easingDirectionFunc = _easingDirection[easingDirection.Name]
	return easingDirectionFunc(alpha, easingStyleFunc)
end

function Module.getActualFriction(propA: PhysicalProperties, propB: PhysicalProperties): number
	return (propA.Friction * propA.FrictionWeight + propB.Friction * propB.FrictionWeight) / (propA.FrictionWeight + propB.FrictionWeight)
end

-- Converts the Vector3 to a Vector2 by dropping the Z component
function Module.toVect2(v: Vector3): Vector2
	return vect2New(v.X, v.Y)
end

-- Returns 1 if true or -1 if false
function Module.fromBoolean(bool: boolean): number
	return if bool then 1 else -1
end

return Module
