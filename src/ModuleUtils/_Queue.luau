--!strict
--@author: CoderActual
--@date: 10/16/2025
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------

local Trove = require("./_Trove")
local Signal = require("./_Signal")
local FunctionUtils = require("../FunctionUtils")
local t = FunctionUtils.t

-----------------------------
-- TYPES --
-----------------------------

export type Queue<T> = {
	_trove: Trove.TroveType,
	_userData: { [any]: any },
	_first: number,
	_last: number,
	_queue: { T },
	
	GetTrove: (self: Queue<T>) -> Trove.TroveType,
	GetUserData: (self: Queue<T>) -> { [any]: any },
	IsEmpty: typeof(
		--[[
			Returns true if there is nothing in the Queue
		]]
		function(self: Queue<T>): boolean
			return nil :: any
		end
	),
	GetCount: typeof(
		-- Returns the current queue count
		function(self: Queue<T>): number
			return nil :: any
		end
	),
	
	Peek: typeof(
		-- Returns the next object from queue without removing it.
		function(self: Queue<T>): T?
			return nil :: any
		end
	),
	Enqueue: typeof(
		-- Adds an object to the queue and returns position in queue
		function(self: Queue<T>, value: T | { T }): number
			return nil :: any
		end
	),
	Dequeue: typeof(
		-- Remove a value from the queue and returns it
		function(self: Queue<T>): T
			return nil :: any
		end
	),
	
	Signals: {
		EnqueuedSignal: Signal.GenericSignal,
		DequeuedSignal: Signal.GenericSignal,
	}
}

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- CLASS FUNCTIONS --
-----------------------------

function Module.new<T>(): Queue<T>
	local self = setmetatable({} :: any, MT) :: Queue<T>
	self._trove = Trove.new()
	self._userData = {}
	
	self._first = 0
	self._last = -1
	self._queue = {}
	
	self.Signals = {
		EnqueuedSignal = self._trove:Construct(Signal.new()),
		DequeuedSignal = self._trove:Construct(Signal.new()),
	}

	return self
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object) == MT
end

-----------------------------
-- METHODS --
-----------------------------

-- Check if the queue is empty
function MT.IsEmpty<T>(self: Queue<T>)
	return self._first > self._last
end


function MT.Peek<T>(self: Queue<T>, value: T): T?
	if self:IsEmpty() then
		return nil
	end
	return self._queue[self._first]
end

function MT.Enqueue<T>(self: Queue<T>, value: T | { T }): number
	local last: number
	if t.table(value) then
		for _, val in ipairs(value :: { T }) do
			last = self._last + 1
			self._last = last
			self._queue[last] = val :: T
		end
	else
		last = self._last + 1
		self._last = last
		self._queue[last] = value :: T
	end
	
	self.Signals.EnqueuedSignal:FireDefer()
	
	return last
end

function MT.Dequeue<T>(self: Queue<T>): T
	if self:IsEmpty() then
		error("Cannot dequeue from empty queue", 2)
	end

	local first = self._first
	local value = self._queue[first]
	self._queue[first] = nil
	self._first = first + 1

	self.Signals.DequeuedSignal:FireDefer()

	return value
end

-----------------------------
-- SETTERS --
-----------------------------

-----------------------------
-- GETTERS --
-----------------------------

function MT.GetTrove(self: Queue<any>): Trove.TroveType
	return self._trove
end

function MT.GetUserData(self: Queue<any>): { [any]: any }
	return self._userData
end

-----------------------------
-- CLEANUP --
-----------------------------

function MT.Destroy(self: Queue<any>)
	self._trove:Clean()
end

-----------------------------
-- MAIN --
-----------------------------
return Module
