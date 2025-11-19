--!strict
--!optimize 2

local RunService = game:GetService('RunService')

local main = script.Parent

local Zones = {
	ActiveZones = {},
	TotalZoneVolume = 0,
}

function Zones.registerZone(zone: any, options: any)
	Zones.ActiveZones[zone] = options
end

function Zones.deregisterZone(zone: any)
	Zones.ActiveZones[zone] = nil
end

RunService.PostSimulation:Connect(function(dt)
	for zone, params in Zones.ActiveZones do
		local queryOp = params.QueryOptions
		
		local now = os.clock()
		if now - zone.LastUpdate < queryOp.UpdateInterval then
			continue
		end
		zone.LastUpdate = now
		
		local fmode = queryOp.FireMode
		local onEnter = (fmode == "OnEnter" or fmode == "Both") and (fmode::any) ~= "None"
		local onExit = (fmode == "OnExit" or fmode == "Both") and (fmode::any) ~= "None"
		
		if queryOp.InSeperateQuerySpace then
			local worldModel: WorldRoot = zone.WorldRoot
			local querySpace = zone.QuerySpace
			if not querySpace then warn("a") return end
			local dynamic = querySpace.dynamic
			
			local cframes = table.create(#dynamic.replicas)
			
			for index, part in dynamic.index do
				cframes[index] = part.CFrame
			end
			worldModel:BulkMoveTo(dynamic.replicas, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
		
		local overlapParams
		local queryParams = params.QueryParams
		
		if typeof(queryParams) == "function" then
			overlapParams = queryParams(zone)
		else
			overlapParams = queryParams
		end
		zone:Update(overlapParams, onEnter, onExit)
	end
end)

return Zones