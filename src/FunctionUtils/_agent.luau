--!strict
--@author: crusherfire
--@date: 7/8/25
--[[@description:
	Useful utility functions for pathfinding agents/AI
]]
-----------------------------
-- SERVICES --
-----------------------------
local PathfindingService = game:GetService("PathfindingService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local _game = require("./_game")
local Trove = require("../ModuleUtils/_Trove")

-----------------------------
-- TYPES --
-----------------------------
local GlobalTypes = require("../GlobalTypes")

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

--[[
	YIELDS!
	Calculates a path based on the given agent parameters.
]]
function Module.generatePathAsync(startPosition: Vector3, goalPosition: Vector3, agentParams: GlobalTypes.AgentParameters?): Path
	local path = PathfindingService:CreatePath(agentParams) :: Path
	path:ComputeAsync(startPosition, goalPosition)
	return path
end

--[[
	YIELDS!
	Has the agent follow a generated path.
	This will automatically <code>:MoveTo()</code> the agent unless <code>onStep</code> is given for custom behavior.
	<strong>OnStep</strong>: For implementing your own custom MoveTo logic for pathfinding to the waypoint. Return true to cancel the path.
	<strong>OnTimeout</strong>: Called if the agent times out when trying to move to the next waypoint. Return true to cancel the path.
	<strong>OnPathBlocked</strong>: Called when the path becomes blocked at a future waypoint. The pathing will automatically stop when blocked.
	<strong>MoveTimeout</strong>: How long to wait for <code>MoveToFinished</code>. Default is 3 seconds. Cannot be longer than 8.
]]
function Module.followPathAsync(
	humanoid: Humanoid,
	path: Path,
	options: GlobalTypes.FollowPathOptions?
): GlobalTypes.FollowPathResult
	local includeBlocked = if options then options.IncludePathBlocked or false else false
	local waypoints: { PathWaypoint } = path:GetWaypoints()
	local thread = coroutine.running()
	local moveTimeout = math.clamp(if options then options.MoveTimeout or 3 else 3, 0, 8)
	local lastIndex = 0
	local result: GlobalTypes.FollowPathResult = {
		LastWaypoint = waypoints[1],
		TimedOut = false,
		ReachedEnd = false,
		PathWasBlocked = false
	}
	
	local trove = Trove.new()
	if includeBlocked then
		trove:Connect(path.Blocked, function(blockedWaypointIndex)
			if blockedWaypointIndex < lastIndex then
				return
			end
			trove:Clean()
			result.ReachedEnd = false
			result.PathWasBlocked = true
			if options and options.OnPathBlocked then
				task.spawn(options.OnPathBlocked, blockedWaypointIndex, lastIndex)
			end
			if coroutine.status(thread) == "suspended" then
				task.spawn(thread, result)
			end
		end)
	end
	
	trove:Add(task.defer(function()
		local lastReachedWaypoint: number?
		for index, waypoint in waypoints do
			-- Check if the calling thread is still waiting for us
			if coroutine.status(thread) ~= "suspended" then
				-- Calling thread was cancelled or finished, stop following the path
				trove:Clean()
				return
			end
			
			lastIndex = index
			result.LastWaypoint = waypoint
			if options and options.OnStep then
				local shouldStop = options.OnStep(waypoint)
				if shouldStop == true then
					-- don't go to waypoint
					break
				end
			else
				humanoid:MoveTo(waypoint.Position)
				if waypoint.Action == Enum.PathWaypointAction.Jump then
					humanoid.Jump = true
				end
			end
			local timedOut = _game.waitWithTimeout(humanoid.MoveToFinished, moveTimeout)
			if timedOut and options and options.OnTimeout then
				local shouldStop = options.OnTimeout(waypoint)
				if shouldStop then
					result.TimedOut = true
					result.ReachedEnd = false
					break
				end
			else
				lastReachedWaypoint = index
			end
		end
		
		if
			not result.TimedOut
			and lastReachedWaypoint
			and lastReachedWaypoint == #waypoints
		then
			result.ReachedEnd = true
		end
		
		trove:Clean()
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, result)
		end
	end))
	
	return coroutine.yield()
end

-----------------------------
-- MAIN --
-----------------------------
return Module