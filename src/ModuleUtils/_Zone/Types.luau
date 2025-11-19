local main = script.Parent

local Zone = require(main.SimpleZone)
local ZoneOccupancy = require("./ZoneOccupancy")

type LessSimpleZoneInternal<U, T...> = {
	GetPartOccupancyFraction: typeof(
		--[[
			Determines how much of <code>part</code> volume is inside of the zone.
			Defaults to a box check for mesh/union parts.
			<strong>VoxelSize</strong>: Grid spacing (studs). Smaller = slower, more accurate (default is heuristic)
			<strong>MaxSamples</strong>: Safety cap (default 60000).
			<strong>UseRandomJitter</strong>: Reduces aliasing on boundaries (default false)
		]]
		function(self: Zone, part: BasePart, options: ZoneOccupancy.Options?): number
			return 0
		end
	),
	UpdateVolume: typeof(
		--[[
			Updates the volume of this <code>Zone</code>.
		]]
		function(self: LessSimpleZone<U, T...>, ...: T...)
		end
	),
	GetRandomPoint: typeof(
		--[[
			Gets a random point within this <code>Zone</code>.
		]]
		function(self: LessSimpleZone<U, T...>): vector
		end
	),
	IsPointWithinZone: typeof(
		--[[
			Checks if <code>point</code> is located within this <code>Zone</code>.
		]]
		function(self: LessSimpleZone<U, T...>, point: vector): (boolean, U?)
		end
	),
	IsBoxWithinZone: typeof(
		--[[
			Checks if <code>box</code> is within this <code>Zone</code>.
		]]
		function(self: LessSimpleZone<U, T...>, cframe: CFrame, size: vector): (boolean, U?)
		end
	),
	CombineWith: typeof(
		--[[
			Combines this <code>Zone</code>s volume with <code>other</code>.
		]]
		function(self: LessSimpleZone<U, T...>, other: LessSimpleZone<U, T...>)
		end
	),
	
	ZoneType: string,
	Volume: any
}

export type LessSimpleZone<U, T...> = Zone.Zone & LessSimpleZoneInternal<U, T...>

return nil