--!strict
--@author: crusherfire
--@date: 2/12/25
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

-- This isn't perfect since terrain may not fill up an entire voxel.
function Module.getTerrainMaterialAtPosition(pos: Vector3): Enum.Material
	local region = Module.fromPositionAndSize(pos, Vector3.one / 50):ExpandToGrid(4)
	local materials = workspace.Terrain:ReadVoxels(region, 4)
	return materials[1][1][1]
end

function Module.getTerrainRegion3(position: Vector3, size: Vector3, resolution: number): Region3
	return Module.fromPositionAndSize(position, size):ExpandToGrid(resolution)
end

function Module.fromPositionAndSize(pos: Vector3, size: Vector3): Region3
	local halfSize = size / 2
	return Region3.new(pos - halfSize, pos + halfSize)
end

-----------------------------
-- MAIN --
-----------------------------
return Module