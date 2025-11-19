--!optimize 2
--!strict

local main = script.Parent.Parent.Parent

local Types = require(main.Types)

local PartQueryJumpTable: {[string]: (_: WorldRoot, _: BasePart, _: OverlapParams?) -> {BasePart}} = {
	Block = function(worldModel, part, params)
		return worldModel:GetPartBoundsInBox(part.CFrame, part.Size, params)
	end,
	Ball = function(worldModel, part, params)
		return worldModel:GetPartBoundsInRadius(part.Position, part.ExtentsSize.Y, params)
	end
}

return function(self: Types.LessSimpleZone<any>, params)
	debug.profilebegin("LessSimpleZone::PartQueryFunction")
	local querySpace = self.QuerySpace
	local queryOp = self.QueryOptions
	local worldModel = self.WorldRoot
	
	local zonePlace = if querySpace ~= nil then (queryOp.Static and querySpace.static or querySpace.dynamic) else nil
	
	local boxes = self.Volume.boxes
	local parts = self.Volume.parts
	local bvh = self.Volume.bvh
	
	local result: {any} = {}
	
	local totalZoneVolume = 0
	for _, v in boxes do
		local size = v.size
		totalZoneVolume += size.X * size.Y * size.Z
	end
	
	local wholeCheck = worldModel:GetPartBoundsInBox(bvh.cframe, bvh.size, params)
	if #wholeCheck == 0 then
		debug.profileend()
		return result
	end

	for _, part in parts do
		local query: {BasePart}
		if part:IsA("Part") then
			local fn = PartQueryJumpTable[part.Shape.Name]
			query = fn and fn(worldModel, part, params) or worldModel:GetPartsInPart(part, params)
		else
			query = worldModel:GetPartsInPart(part, params)
		end

		if queryOp.AcceptMetadata then
			if queryOp.InSeperateQuerySpace and zonePlace then
				local index = table.find(zonePlace.replicas, part)
				if index then
					part = zonePlace.index[index]
				end
			end

			for _, item in query do
				table.insert(result, {item = item, metadata = {part = part}})
			end
		else
			table.move(query, 1, #query, #result + 1, result)
		end
	end
	
	-- This previous system is incredibly unoptimized!
	--[[if totalVolume > totalZoneVolume then
		-- migrated to above
	else
		for _, item in Tracker.items do
			local succ, part
			if self.ZoneType == "Parts" then
				succ, part = self:IsBoxWithinZone(item.CFrame, item.Size::any)
				if not succ then continue end
			else
				succ, part = self:IsPointWithinZone(item.Position::any)
				if not succ then continue end
			end
			if queryOp.AcceptMetadata then
				table.insert(result, {item = item, metadata = {part = part}})
			else
				table.insert(result, item)
			end
		end
	end]]
	debug.profileend()
	
	return result
end