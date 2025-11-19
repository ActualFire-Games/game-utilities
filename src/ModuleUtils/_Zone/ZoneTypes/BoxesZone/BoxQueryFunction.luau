--!optimize 2
--!strict

local main = script.Parent.Parent.Parent
local module = main.SimpleZone

local Tracker = require(module.Tracker)
local Types = require(main.Types)

return function(self: Types.LessSimpleZone<any>, params)
	debug.profilebegin("LessSimpleZone::BoxQueryFunction")
	local queryOp = self.QueryOptions
	local querySpace = self.QuerySpace
	local worldModel = self.WorldRoot
	
	local boxes = self.Volume.boxes
	local bvh = self.Volume.bvh
	local result: {any} = {}
	
	local totalZoneVolume = 0
	for _, v in boxes do
		local size = v.size
		totalZoneVolume += size.X * size.Y * size.Z
	end
	local totalVolume = Tracker.getTotalVolume() - totalZoneVolume
	
	if totalVolume > totalZoneVolume then
		local wholeCheck = worldModel:GetPartBoundsInBox(bvh.cframe, bvh.size, params)
		if #wholeCheck == 0 then
			debug.profileend()
			return result
		end
		
		for _, box in boxes do
			local query = worldModel:GetPartBoundsInBox(box.cframe, box.size::any, params)
			if #query == 0 then continue end

			if self.QueryOptions.AcceptMetadata then
				for _, item in query do
					table.insert(result, {item = item, metadata = {box = box}})
				end
			else
				table.move(query, 1, #query, #result + 1, result)
			end
		end
	else
		for _, item in Tracker.items do
			local succ, box = self:IsBoxWithinZone(item.CFrame, item.Size::any)
			if not succ then continue end
			if queryOp.AcceptMetadata then
				table.insert(result, {item = item, metadata = {box = box}})
			else
				table.insert(result, item)
			end
		end
	end
	debug.profileend()
	
	return result
end