--!strict
--@author: CoderActual & crusherfire
--@date: 2/14/2025
--[[@description:
	Batches data together and dispatches after a defined time of yielding.
	This is useful for when, for example, you fire the same remote event multiple times in a single frame (like for VFX).
	It would be more performant to batch the remote data together and then send it all at once through one remote event call!
	
	~--~ EXAMPLE ~--~
	local vfxBatcher = ModuleUtils.Batcher.new(-1)
	
	vfxBatcher:Queue(function(userData: BatchedVFXData)
		for _, player in ipairs(players) do
			if not userData[player] then
				userData[player] = {}
			end
			if not userData[player][vfxName] then
				userData[player][vfxName] = {}
			end
			table.insert(userData[player][vfxName], args)
		end
	end)
	
	vfxBatcher:OnFlushed(function(userData: BatchedVFXData)
		for player, vfxWithArgs in pairs(userData) do
			bulkFromServerEvent:FireClient(player, vfxWithArgs)
		end
	end)
]]

-----------------------------
-- SERVICES --
-----------------------------
local RunService = game:GetService("RunService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Trove = require("./_Trove")

-----------------------------
-- TYPES --
-----------------------------
-- This is for all of the properties of an object made from this class for type annotation purposes.
type self = {
	_trove: Trove.TroveType,
	_delayDuration: number,
	_onFlushed: OnFlushedFunc?,
	_userData: UserData,
	_flushScheduled: boolean,
}

type UserData = { [any]: any }
export type OnFlushedFunc = (userData: UserData) -> ()

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT
export type Batcher = typeof(setmetatable({} :: self, MT))

-- CONSTANTS --
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates a new batcher.
-- <strong>duration</strong>: Defines how the batcher should yield before flushing. Default is heartbeat.
-- <strong>-2</strong> delays to next heartbeat (task.wait),
-- <strong>-1</strong> delays to end of invocation cycle (task.defer),
-- <strong>0</strong> delays to next frame (RunService.RenderStepped:Wait())
function Module.new(duration: (number | "heartbeat" | "defer" | "renderstep")?): Batcher
	local self = setmetatable({} :: self, MT)

	local duration =
		if typeof(duration) == "number" then duration
		elseif duration == "heartbeat" then -2
		elseif duration == "defer" then -1
		elseif duration == "renderstep" then 0
		else -2

	self._trove = Trove.new()
	self._delayDuration = duration
	self._userData = {}
	self._flushScheduled = false

	return self
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object).__index == MT
end

-- Gets the user data for the current batch cycle.
-- User data is automatically set to a new table when the batcher flushes.
function MT.GetUserData(self: Batcher)
	return self._userData
end

-- Calls <code>callback</code> immediately, allowing you to structure <code>userData</code>.
-- Schedules a flush if one isn't already.
function MT.Queue(self: Batcher, callback: (userData: UserData) -> ())
	assert(self._onFlushed, "No function exists to handle batch dispatches!")
	callback(self._userData)
	if not self:IsFlushScheduled() then
		self._flushScheduled = true
		if self._delayDuration == -2 then
			-- yields for next heartbeat
			self._trove:Add(task.spawn(function()
				task.wait()
				self:_Flush()
				self._trove:Remove(coroutine.running()) -- don't leak this thread
			end))
		elseif self._delayDuration == -1 then
			-- yields to end of invocation cycle
			self._trove:Add(task.defer(function()
				self:_Flush()
				self._trove:Remove(coroutine.running()) -- don't leak this thread
			end))
		elseif self._delayDuration == 0 then
			-- yields to next frame
			self._trove:Add(task.spawn(function()
				RunService.RenderStepped:Wait()
				self:_Flush()
				self._trove:Remove(coroutine.running()) -- don't leak this thread
			end))
		else
			-- yields based on delay duration
			self._trove:Add(task.delay(self._delayDuration, function()
				self:_Flush()
				self._trove:Remove(coroutine.running()) -- don't leak this thread
			end))
		end
	end
end

-- Flushes the batched user data and resets it.
function MT._Flush(self: Batcher)
	assert(self._onFlushed, "No function exists to handle batch dispatches!")
	self._onFlushed(self._userData)
	self._flushScheduled = false
	self._userData = {}
end

-- Sets the function that gets called when the batch is flushed.
-- Only one callback exists at a time.
function MT.OnFlushed(self: Batcher, onFlushed: OnFlushedFunc)
	self._onFlushed = onFlushed
end

function MT.IsFlushScheduled(self: Batcher): boolean
	return self._flushScheduled
end

function MT.Destroy(self: Batcher)
	self._trove:Clean()
end
-----------------------------
-- MAIN --
-----------------------------
return Module
