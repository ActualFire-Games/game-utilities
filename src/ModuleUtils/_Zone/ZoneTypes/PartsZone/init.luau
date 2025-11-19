--!optimize 2
--!strict

local main = script.Parent.Parent
local module = main.SimpleZone

local Types = require(main.Types)
local Zone = require(module)
local Geometry = require(main.Geometry)

local PartQueryFunction = require(script.PartQueryFunction)
local ZoneOccupancy = require("../ZoneOccupancy")

local BVH = Geometry.BVH
local UtilityFunctions = require(module.Utility.UtilityFunctions)
local t = require(module.Utility.t)

local t_assert = t.t_assert
local T_TYPES = UtilityFunctions.TTypes

local Vertices = Geometry.Vertices

local RANDOM_POINT_DIMENSION = 3

@native
local function getVolume(parts: {Part})
	local boxes, points, partToPointIndex = Geometry.getBoxesVerticesForParts(Vertices, parts)
	local bvh = BVH.createBVH(boxes)
	
	return {
		partToPointIndex = partToPointIndex,
		points = points,
		boxes = boxes,
		parts = parts,
		bvh = bvh
	}
end

type Box = Geometry.Box
export type PartsZone = Types.LessSimpleZone<Part, {Part}>

local PartsZone = {}

@native function PartsZone.UpdateVolume(self: PartsZone, parts: {Part})
	t_assert("parts", parts, T_TYPES.partArray, "{Part}")
	
	local boxes, points, partToPointIndex = Geometry.getBoxesVerticesForParts(Vertices, parts)
	
	local volume = self.Volume
	local success, updated = BVH.updateBVH(volume.bvh, volume.boxes, boxes)
	
	if not success then return end
	
	self.Volume = {
		partToPointIndex = partToPointIndex,
		points = points,
		boxes = boxes,
		parts = parts,
		bvh = updated
	}
end

@native function PartsZone.GetRandomPoint(self: PartsZone): vector
	local points = self.Volume.points

	local randomvgroup = points[math.random(1, #points)]

	return Geometry.getRandomPointInSimplex(RANDOM_POINT_DIMENSION, randomvgroup)
end

@native function PartsZone.IsPointWithinZone(self: PartsZone, point: vector)
	t_assert("point", point, "vector")
	
	local bvh = self.Volume.bvh
	
	if not Geometry.isPointInBox(bvh.cframe, bvh.size, point) then
		return false
	end
	
	local isPointWithinZone = false
	local part = nil
	
	BVH.traverseBVH(bvh, function(box, stop)
		if isPointWithinZone then
			return false
		end
		if not Geometry.isPointInBox(box.cframe, box.size, point) then
			return false
		end
		-- If not yet at a leaf node, keep going
		if box.left or box.right then
			return true
		end
		assert(box.part ~= nil and box.part:IsA("Part"), "invalid part type, expected Part")
		
		-- Is a leaf node
		if not Geometry.isPointInShape(point, box.part) then
			return false
		end
		
		isPointWithinZone = true
		part = box.part
		stop()
		return false
	end)
	return isPointWithinZone, part
end

@native function PartsZone.IsBoxWithinZone(self: PartsZone, cframe: CFrame, size: vector)
	t_assert("cframe", cframe, "CFrame")
	t_assert("size", size, "vector")
	debug.profilebegin("PartsZone::IsBoxWithinZone")
	local bvh = self.Volume.bvh
	if not Geometry.doBoxesIntersect(cframe, size, bvh.cframe, bvh.size) then
		debug.profileend()
		return false
	end

	local isPointWithinZone = false
	local part = nil
	
	BVH.traverseBVH(bvh, function(box, stop)
		if isPointWithinZone then
			return false
		end
		if not Geometry.doBoxesIntersect(cframe, size, box.cframe, box.size) then
			return false
		end
		-- If not yet at a leaf node, keep going
		if box.left or box.right then
			return true
		end
		assert(box.part ~= nil and box.part:IsA("Part"), "invalid part type, expected Part")
		-- Is a leaf node
		if not Geometry.isBoxInShape(cframe, size, box.part) then
			return false
		end

		isPointWithinZone = true
		part = box.part
		stop()
		return false
	end)
	debug.profileend()
	return isPointWithinZone, part
end

@native function PartsZone.CombineWith(self: PartsZone, other)
	assert(other.ZoneType == "Parts", "Can only merge Boxes zones with other Boxes zones.")
	local otherV = other.Volume

	local thisParts = self.Volume.parts
	local mergedParts = table.move(otherV.parts, 1, #otherV.parts, #thisParts+1, thisParts)

	self:UpdateVolume(mergedParts)
end

-- Creates a new <code>Zone</code> based on an array of Parts.
local function pz_new(parts: {Part}, queryOp: Zone.QueryOptions?)
	local volume = getVolume(parts)
	
	local zone = Zone.fromCustom(PartQueryFunction :: any, queryOp) :: PartsZone
	zone.UpdateVolume 		= PartsZone.UpdateVolume
	zone.GetRandomPoint 	= PartsZone.GetRandomPoint
	zone.IsPointWithinZone 	= PartsZone.IsPointWithinZone
	zone.IsBoxWithinZone 	= PartsZone.IsBoxWithinZone
	zone.CombineWith 		= PartsZone.CombineWith
	
	zone.ZoneType 			= "Parts"
	zone.Volume 			= volume
	
	ZoneOccupancy.Attach(zone)
	
	return zone
end

return pz_new