--!optimize 2
--!strict
--[[
	This is a MODIFIED version of LessSimpleZone by @athar_adv (modified by @crusherfire (8/8/25))
	
	- Adds a few fixes
	- Makes the volume tracking system much more performant
	- Fixes an error with thread recycling
	- New method :GetPartOccupancyFraction()
]]

local zoneTypes = script.ZoneTypes

local Types = require(script.Types)
local SimpleZone = require(script.SimpleZone)
local Geometry = require(script.Geometry)

export type LessSimpleZone<U, T...> = Types.LessSimpleZone<U, T...>
export type Zone = SimpleZone.Zone
export type PartsZone = Types.LessSimpleZone<BasePart, { BasePart }>
export type BoxesZone = Types.LessSimpleZone<Geometry.BoxNode, { Geometry.Box }>

export type QueryOptions = SimpleZone.QueryOptions
export type Box = SimpleZone.Box

return table.freeze {
	fromBoxes = require(zoneTypes.BoxesZone),
	fromParts = require(zoneTypes.PartsZone),
	fromBasePartsVertices = require(zoneTypes.BasePartsVertexZone),
	
	SimpleZone = SimpleZone,
	QueryOptions = SimpleZone.QueryOptions,
	Geometry = require(script.Geometry)
}