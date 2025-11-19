--!optimize 2
--!strict

local main = script.Parent.Parent
local module = main.SimpleZone

local Types = require(main.Types)
local Zone = require(module)
local Geometry = require(main.Geometry)

local PartQueryFunction = require(script.Parent.PartsZone.PartQueryFunction)
local ZoneOccupancy = require("../ZoneOccupancy")

local BVH = Geometry.BVH
local UtilityFunctions = require(module.Utility.UtilityFunctions)
local t = require("../SimpleZone/Utility/t")

local t_assert = t.t_assert
local T_TYPES = UtilityFunctions.TTypes

local RANDOM_POINT_DIMENSION = 3

type Box = Geometry.Box

@native
local function getVolume(parts: {BasePart}, vertices: {Vector3})
	local tetrahedrons = Geometry.generateTetrahedrons(vertices)
	local boxes: {Box} = {}
	
	for _, part in parts do
		table.insert(boxes, {
			cframe = part.CFrame,
			size = (part.Size :: any) :: vector,
			part = part
		})
	end
	for i, tetra in tetrahedrons do
		local tbl = {}
		tbl.t = tetra
		tbl.bound = {Geometry.getBoundingBox(tetra)}
		tetrahedrons[i] = tbl
	end
	
	local bvh = BVH.createBVH(boxes)
	
	return {
		parts = parts,
		points = vertices,
		tetrahedrons = tetrahedrons,
		boxes = boxes,
		bvh = bvh
	}
end

export type BasePartsVertexZone =  Types.LessSimpleZone<{bound: {CFrame & Vector3}, t: {Vector3}}, ({BasePart}, {Vector3})>

local BasePartsVertexZone = {}

@native function BasePartsVertexZone.UpdateVolume(self: BasePartsVertexZone, parts: {BasePart}, vertices: {Vector3})
	t_assert("parts", parts, T_TYPES.partArray, "{BasePart}")
	
	local tetrahedrons = Geometry.generateTetrahedrons(vertices)
	local boxes = {}

	for _, part in parts do
		table.insert(boxes, {
			cframe = part.CFrame,
			size = part.Size,
			part = part
		})
	end
	for i, tetra in tetrahedrons do
		local tbl = {}
		tbl.t = tetra
		tbl.bound = {Geometry.getBoundingBox(tetra)}
		tetrahedrons[i] = tbl
	end
	
	local volume = self.Volume
	local success, updated = BVH.updateBVH(volume.bvh, volume.boxes, boxes::any)
	
	if not success then return end
	
	self.Volume = {
		parts = parts,
		points = vertices,
		tetrahedrons = tetrahedrons,
		boxes = boxes,
		bvh = updated
	}
end

@native function BasePartsVertexZone.GetRandomPoint(self: BasePartsVertexZone)
	local points = self.Volume.points

	local randomvgroup = points[math.random(1, #points)]

	return Geometry.getRandomPointInSimplex(RANDOM_POINT_DIMENSION, randomvgroup)
end

@native function BasePartsVertexZone.IsPointWithinZone(self: BasePartsVertexZone, point: vector)
	t_assert("point", point, "vector")
	
	for _, tetra in self.Volume.tetrahedrons do
		local bound = tetra.bound
		local cf, size = bound[1], bound[2]
		
		local halfSize = size / 2
		local localPoint = cf:PointToObjectSpace(point)

		local withinX = math.abs(localPoint.X) <= halfSize.X
		local withinY = math.abs(localPoint.Y) <= halfSize.Y
		local withinZ = math.abs(localPoint.Z) <= halfSize.Z

		if not (withinX and withinY and withinZ) then
			return false
		end
		if not Geometry.isPointInTetrahedron(point, unpack(tetra.t)) then continue end
		
		return true, tetra
	end
	return false
end

@native function BasePartsVertexZone.IsBoxWithinZone(self: BasePartsVertexZone, cframe: CFrame, size: vector)
	t_assert("cframe", cframe, "CFrame")
	t_assert("size", size, "vector")
	
	error("BasePartsVertexZone:IsBoxWithinZone() is not implemented yet.")
	return false, nil
end

@native function BasePartsVertexZone.CombineWith(self: BasePartsVertexZone, other)
	assert(other.ZoneType == "BasePartsVertex", "Can only merge Boxes zones with other Boxes zones.")
	local otherV = other.Volume

	local thisparts = self.Volume.parts
	local thisPoints = self.Volume.points
	local mergedParts = table.move(otherV.parts, 1, #otherV.parts, #thisparts+1, thisparts)
	local mergedPoints = table.move(otherV.points, 1, #otherV.points, #thisPoints+1, thisPoints)

	self:UpdateVolume(mergedParts, mergedPoints)
end

-- Creates a new <code>Zone</code> using an array of BaseParts and vertices defining the bounds of each one.
local function bvz_new(parts: {BasePart}, vertices: {Vector3}, queryOp: Zone.QueryOptions?)
	local volume = getVolume(parts, vertices)

	local zone = Zone.fromCustom(PartQueryFunction :: any, queryOp) :: BasePartsVertexZone
	zone.UpdateVolume 		= BasePartsVertexZone.UpdateVolume
	zone.GetRandomPoint 	= BasePartsVertexZone.GetRandomPoint
	zone.IsPointWithinZone 	= BasePartsVertexZone.IsPointWithinZone
	zone.IsBoxWithinZone 	= BasePartsVertexZone.IsBoxWithinZone
	zone.CombineWith 		= BasePartsVertexZone.CombineWith

	zone.ZoneType 			= "BasePartsVertex"
	zone.Volume 			= volume
	
	ZoneOccupancy.Attach(zone)
	
	return zone
end

return bvz_new