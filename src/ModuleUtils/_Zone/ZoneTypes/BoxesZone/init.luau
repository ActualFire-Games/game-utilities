--!optimize 2
--!strict

local main = script.Parent.Parent
local module = main.SimpleZone

local Types = require(main.Types)
local Zone = require(module)
local Geometry = require(main.Geometry)

local BoxQueryFunction = require(script.BoxQueryFunction)
local ZoneOccupancy = require("../ZoneOccupancy")

local BVH = Geometry.BVH
local UtilityFunctions = require(module.Utility.UtilityFunctions)
local t = require(module.Utility.t)

local t_assert = t.t_assert
local T_TYPES = UtilityFunctions.TTypes

type Box = Geometry.Box
type BoxNode = Geometry.BoxNode

@native
local function initializeVolume(boxes: {Box})
	local bvh = BVH.createBVH(boxes)
	local leaves = {}

	BVH.traverseBVH(bvh, function(box)
		if not box.left and not box.right then
			table.insert(leaves, box)
			return false
		end
		return true
	end)

	return {
		bvh = bvh,
		leaves = leaves
	}
end

export type BoxesZone = Types.LessSimpleZone<BoxNode, {Box}>

local BoxesZone = {}

@native function BoxesZone.UpdateVolume(self: BoxesZone, boxes: {Box})
	t_assert("boxes", boxes, T_TYPES.boxArray, "{Box}")
	
	local volume = self.Volume
	local success, updated = BVH.updateBVH(volume.bvh, volume.boxes, boxes)
	
	-- It means no changes could be made
	if not success then return end
	
	local leaves = {}

	BVH.traverseBVH(updated, function(box)
		if not box.left and not box.right then
			table.insert(leaves, box)
			return false
		end
		return true
	end)
	
	self.Volume = {
		bvh = updated,
		boxes = boxes,
		leaves = leaves
	}
end

@native function BoxesZone.GetRandomPoint(self: BoxesZone): vector
	local leafNodes = self.Volume.leaves

	assert(#leafNodes > 0, "No leaf nodes found in BVH")
	
	local randomLeaf = leafNodes[math.random(1, #leafNodes)]
	local cframe, size = randomLeaf.cframe, randomLeaf.size

	local randomX = math.random() * size.X - size.X / 2
	local randomY = math.random() * size.Y - size.Y / 2
	local randomZ = math.random() * size.Z - size.Z / 2

	local randomPoint = cframe:PointToWorldSpace(vector.create(randomX, randomY, randomZ))

	return randomPoint
end

@native function BoxesZone.IsPointWithinZone(self: BoxesZone, point: vector)
	t_assert("point", point, "vector")
	
	local bvh = self.Volume.bvh
	if not Geometry.isPointInBox(bvh.cframe, bvh.size, point) then
		return false
	end
	local found = false
	local foundBox = nil
	
	BVH.traverseBVH(bvh, function(box, stop)
		if found then
			return false
		end
		if not Geometry.isPointInBox(box.cframe, box.size, point) then
			return false
		end
		if box.left or box.right then
			return true
		end
		found = true
		foundBox = box
		
		stop() -- Point is within a leaf node, no need to continue
		return false
	end)
	
	return found, foundBox
end

@native function BoxesZone.IsBoxWithinZone(self: BoxesZone, cframe: CFrame, size: vector)
	t_assert("cframe", cframe, "CFrame")
	t_assert("size", size, "vector")
	
	local found = false
	local foundBox = nil
	
	local bvh = self.Volume.bvh
	if not Geometry.doBoxesIntersect(cframe, size, bvh.cframe, bvh.size) then
		return false
	end
	
	BVH.traverseBVH(bvh, function(node, stop)
		if found then
			return false
		end
		if not Geometry.doBoxesIntersect(cframe, size, node.cframe, node.size) then
			return false
		end
		-- If it's an internal node, continue traversing
		if node.left or node.right then
			return true
		end
		
		-- Found a leaf node intersection
		found = true
		foundBox = node

		stop() -- Stop traversal
		return false
	end)

	return found, foundBox
end

@native function BoxesZone.CombineWith(self: BoxesZone, other)
	assert(other.ZoneType == "Boxes", "Can only merge Boxes zones with other Boxes zones.")
	local otherV = other.Volume

	local thisBoxes = self.Volume.boxes
	local mergedBoxes = table.move(otherV.boxes, 1, #otherV.boxes, #thisBoxes+1, thisBoxes)

	self:UpdateVolume(mergedBoxes)
end

-- Creates a <code>Zone</code> based on an array of bounding boxes utilizing a BVH structure for optimal efficiency.
local function bz_new(boxes: {Box}, queryOp: Zone.QueryOptions?)
	local volume = initializeVolume(boxes)

	local zone = Zone.fromCustom(BoxQueryFunction :: any, queryOp) :: BoxesZone
	zone.UpdateVolume 		= BoxesZone.UpdateVolume
	zone.GetRandomPoint 	= BoxesZone.GetRandomPoint
	zone.IsPointWithinZone 	= BoxesZone.IsPointWithinZone
	zone.IsBoxWithinZone 	= BoxesZone.IsBoxWithinZone
	zone.CombineWith 		= BoxesZone.CombineWith

	zone.ZoneType 			= "Boxes"
	zone.Volume 			= volume
	
	ZoneOccupancy.Attach(zone)

	return zone
end

return bz_new