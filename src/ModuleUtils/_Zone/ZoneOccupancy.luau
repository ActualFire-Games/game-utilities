--!strict
--!native
-- ZoneOccupancy.lua
-- Attaches GetPartOccupancyFraction(part, options?) to a Zone-like object that implements :IsPointWithinZone(point).

export type Options = {
	VoxelSize: number?,
	MaxSamples: number?,
	UseRandomJitter: boolean?,
}

local DEFAULT_MAX_SAMPLES = 100
local MIN_VOXEL = 1e-3

local abs = math.abs
local floor = math.floor
local min = math.min
local max = math.max
local clamp = math.clamp
local random = math.random

local Vector3_new = Vector3.new

local function chooseVoxelSizeForPart(part: BasePart, userVoxelSize: number?): number
	if userVoxelSize ~= nil then
		if userVoxelSize < MIN_VOXEL then
			return MIN_VOXEL
		end
		return userVoxelSize
	end

	local size = part.Size
	local minDim = min(size.X, min(size.Y, size.Z))
	local steps = clamp(floor(minDim / 0.15), 8, 24)
	if steps <= 0 then
		steps = 8
	end
	return minDim / steps
end

-- Compute lattice counts and step from size and desired voxel
local function latticeFromSize(size: Vector3, voxelSize: number)
	local nx = max(1, floor(size.X / voxelSize))
	local ny = max(1, floor(size.Y / voxelSize))
	local nz = max(1, floor(size.Z / voxelSize))
	local dx = size.X / nx
	local dy = size.Y / ny
	local dz = size.Z / nz
	return nx, ny, nz, dx, dy, dz
end

-- Cheap inlined shape tests in *object space*
local function localPointInsideBlock(hx: number, hy: number, hz: number, x: number, y: number, z: number): boolean
	return abs(x) <= hx and abs(y) <= hy and abs(z) <= hz
end

-- Cylinder aligned to X-axis like Roblox Part.Shape == Cylinder
local function localPointInsideXCylinder(halfHeight: number, radius: number, x: number, y: number, z: number): boolean
	if abs(x) > halfHeight then return false end
	return (y*y + z*z) <= radius * radius
end

local function localPointInsideBall(radius: number, x: number, y: number, z: number): boolean
	return (x*x + y*y + z*z) <= radius * radius
end

local ZoneOccupancy = {}

function ZoneOccupancy.Attach(zone: any)
	function zone:GetPartOccupancyFraction(part: BasePart, options: Options?): number
		assert(typeof(part) == "Instance" and part:IsA("BasePart"), "GetPartOccupancyFraction: 'part' must be a BasePart.")
		assert(typeof(self.IsPointWithinZone) == "function", "GetPartOccupancyFraction requires :IsPointWithinZone(point) on the zone instance.")

		local size = part.Size
		if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
			return 0
		end

		debug.profilebegin("LessSimpleZone::GetPartOccupancyFraction")

		-- ========= Adaptive budget =========
		local function chooseAdaptiveBudget(partSize: Vector3, userMax: number?): number
			if userMax ~= nil then
				return userMax
			end

			-- Heuristic:
			-- - Small parts need more samples to avoid aliasing
			-- - Large parts become expensive quickly; keep samples modest
			local longest = math.max(partSize.X, math.max(partSize.Y, partSize.Z))
			local volume = partSize.X * partSize.Y * partSize.Z

			-- Base around 100; boost a bit for tiny parts; clamp for very large
			local target = 100

			if longest <= 4 then
				target += 50
			end

			-- Add a small volume-based component but clamp to a sane band
			target += math.floor(math.clamp(volume * 0.02, 0, 100))
			target = math.clamp(target, 100, 350)

			return target
		end

		local cf = part.CFrame
		local className = part.ClassName
		local isPart = (className == "Part")
		local shapeEnum = if isPart then (part :: any).Shape else Enum.PartType.Block

		local isBlock = isPart and (shapeEnum == Enum.PartType.Block)
		local isCylinder = isPart and (shapeEnum == Enum.PartType.Cylinder)
		local isBall = isPart and (shapeEnum == Enum.PartType.Ball)

		local maxSamples = chooseAdaptiveBudget(size, if options then options.MaxSamples else nil)
		local useRandomJitter = (options ~= nil and options.UseRandomJitter == true)

		local voxelSize = chooseVoxelSizeForPart(part, if options then options.VoxelSize else nil)
		local nx, ny, nz, dx, dy, dz = latticeFromSize(size, voxelSize)
		local totalGrid = nx * ny * nz

		if totalGrid > maxSamples then
			local scale = (totalGrid / maxSamples) ^ (1 / 3)
			voxelSize *= scale
			nx, ny, nz, dx, dy, dz = latticeFromSize(size, voxelSize)
			totalGrid = nx * ny * nz
		end

		if totalGrid <= 0 then
			debug.profileend()
			return 0
		end

		-- Precompute object-space half extents and shape params
		local hx = size.X * 0.5
		local hy = size.Y * 0.5
		local hz = size.Z * 0.5

		local cylHalfHeight = hx   -- Cylinders align to X in Roblox
		local cylRadius = hy       -- Y == Z for cylinders
		local ballRadius = hx      -- Spheres are uniform

		-- Start coords for lattice centers in object space
		local startX = -hx + dx * 0.5
		local startY = -hy + dy * 0.5
		local startZ = -hz + dz * 0.5

		local jScale = dx
		if dy > jScale then
			jScale = dy
		end
		if dz > jScale then
			jScale = dz
		end

		local jitterAmp = 0
		if useRandomJitter then
			jitterAmp = 0.3 * jScale
		end

		-- Cache the zone query to avoid method lookup in hot path
		local isInsideZone = (self :: any).IsPointWithinZone

		local usedCount = 0
		local insideCount = 0

		-- ========= Early exit controls (CI width) =========
		local MIN_SAMPLES_FOR_EARLY_EXIT = 48        -- don’t exit too early
		local CHECK_EVERY = 16                       -- reduce math frequency
		local CONF_Z = 1.96                          -- ~95% confidence
		local MAX_HALF_WIDTH = 0.05                  -- stop when half-width < 5%

		local function shouldStopEarly(n: number, inside: number): boolean
			if n < MIN_SAMPLES_FOR_EARLY_EXIT then
				return false
			end

			local p = inside / n
			local variance = p * (1 - p)
			if variance <= 0 then
				return true
			end

			local se = math.sqrt(variance / n)
			local halfWidth = CONF_Z * se

			if halfWidth < MAX_HALF_WIDTH then
				return true
			end

			return false
		end

		local stopNow = false

		-- Iterate without closures; compute scalars first; build Vector3 only when needed
		for iz = 0, nz - 1 do
			if stopNow then
				break
			end

			local baseZ = startZ + iz * dz

			for iy = 0, ny - 1 do
				if stopNow then
					break
				end

				local baseY = startY + iy * dy

				for ix = 0, nx - 1 do
					local x = startX + ix * dx
					local y = baseY
					local z = baseZ

					if jitterAmp ~= 0 then
						x += (random() - 0.5) * jitterAmp
						y += (random() - 0.5) * jitterAmp
						z += (random() - 0.5) * jitterAmp
					end

					-- Cheap local-space shape reject
					local passes = false
					if isBlock then
						passes = localPointInsideBlock(hx, hy, hz, x, y, z)
					elseif isCylinder then
						passes = localPointInsideXCylinder(cylHalfHeight, cylRadius, x, y, z)
					elseif isBall then
						passes = localPointInsideBall(ballRadius, x, y, z)
					elseif isPart then
						-- Wedge / CornerWedge: fall back to world test (rare and slow)
						local localV = Vector3_new(x, y, z)
						passes = require(script.Parent.Geometry).isPointInShape(cf:PointToWorldSpace(localV) :: any, part :: Part)
					else
						-- MeshPart/Union/etc.: AABB prefilter, then let the zone decide
						passes = localPointInsideBlock(hx, hy, hz, x, y, z)
					end

					if not passes then
						continue
					end

					usedCount += 1

					local worldP = cf:PointToWorldSpace(Vector3_new(x, y, z))
					if isInsideZone(self, worldP) then
						insideCount += 1
					end

					-- Early exit once stable; never exceed adaptive max
					if (usedCount % CHECK_EVERY == 0) then
						if shouldStopEarly(usedCount, insideCount) then
							stopNow = true
							break
						end
					end

					if usedCount >= maxSamples then
						stopNow = true
						break
					end
				end
			end
		end

		debug.profileend()

		if usedCount == 0 then
			return 0
		end

		return insideCount / usedCount
	end
end

return ZoneOccupancy