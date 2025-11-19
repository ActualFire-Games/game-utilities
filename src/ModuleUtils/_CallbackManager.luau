--!strict
--@author: crusherfire
--@date: 11/20/24
--[[@description:
	A manager for collecting callbacks and firing events when new callbacks are added or removed.
	Similar to the CallbackManager except these callbacks are not required to return booleans and nothing is evaluated.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local FunctionUtils = require("../FunctionUtils")
local t = FunctionUtils.t
local Trove = require(script.Parent._Trove)
local Signal = require(script.Parent._Signal)

-----------------------------
-- TYPES --
-----------------------------
type Callback = (...any) -> ()

type StoredCallback = { Identifier: any, Priority: number, Callback: Callback }

type fields = {
	_trove: Trove.TroveType,
	Signals: {
		CallbackAdded: Signal.SignalType<() -> (), ()>,
		CallbackRemoved: Signal.SignalType<() -> (), ()>
	},
	_callbacksSorted: { StoredCallback },
	_registered: { [string]: boolean },
}

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT
export type CallbackManager = typeof(setmetatable({} :: fields, MT))

-- CONSTANTS --
Module.INVOKE_PRIORITY = {
	FIRST = 0,
	LAST = 2000
}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function getFirstLine(message: string): string
	local first = string.split(message, "\n")[1]
	return first
end

local function safeSpawnInvoke(identifier: string, fn: Callback, ...: any)
	task.spawn(function(...)
		local ok, err = xpcall(function(...)
			fn(...)
		end, debug.traceback, ...)


		if not ok then
			local first = getFirstLine(err :: any)
			local suffix = ""
			local lastColon = string.find(first, ": ")
			if lastColon then
				suffix = first:sub(lastColon + 2)
			else
				suffix = first
			end
			logger:warn(
				string.format("Callback '%s' raised an error: %s\n%s", tostring(identifier), suffix, err),
				true
			)
		end
	end, ...)
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates a new callback manager.
function Module.new(): CallbackManager
	local self = setmetatable({} :: fields, MT)
	
	self._trove = Trove.new()
	self.Signals = {
		CallbackAdded = self._trove:Construct(Signal),
		CallbackRemoved = self._trove:Construct(Signal)
	}
	self._callbacksSorted = {}
	self._registered = {}

	return self
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object).__index == MT
end

function MT._SortCallbacks(self: CallbackManager)
	table.sort(self._callbacksSorted, function(a, b)
		return a.Priority < b.Priority
	end)
end

--[[
	Adds a callback to the the manager.
	<strong>priority</strong>: Smaller values means callback executes sooner. Default is last. Must be a value between FIRST and LAST range.
]]
function MT.AddCallback(self: CallbackManager, identifier: any, callback: Callback, priority: number?)
	assert(t.tuple(t.any, t.callback, t.optional(t.integerConstrained(Module.INVOKE_PRIORITY.FIRST, Module.INVOKE_PRIORITY.LAST)))(identifier, callback, priority))
	if self._registered[identifier] then
		warn(`Overriding callback with identifier: {identifier}`, debug.traceback())
	end
	table.insert(self._callbacksSorted, {
		Identifier = identifier,
		Callback = callback,
		Priority = priority or Module.INVOKE_PRIORITY.LAST
	})
	self:_SortCallbacks()
	self.Signals.CallbackAdded:Fire()
end

function MT.HasCallback(self: CallbackManager, identifier: any): boolean
	return self._registered[identifier] ~= nil
end

function MT.RemoveCallback(self: CallbackManager, identifier: any)
	if not self._registered[identifier] then
		return
	end
	self._registered[identifier] = nil
	for index, info in self._callbacksSorted do
		if info.Identifier == identifier then
			table.remove(self._callbacksSorted, index)
			break
		end
	end
	self:_SortCallbacks()
	self.Signals.CallbackRemoved:Fire()
end

--[[
	Calls all callbacks with the given arguments <code>...</code>.
	Does not yield and has error handling.
]]
function MT.Call(self: CallbackManager, ...: any)
	for _, info in self._callbacksSorted do
		safeSpawnInvoke(info.Identifier, info.Callback, ...)
	end
end

--[[
	Removes all callbacks and cleans the trove.
]]
function MT.Destroy(self: CallbackManager)
	self._trove:Clean()
	table.clear(self._callbacksSorted)
	table.clear(self._registered)
end

-----------------------------
-- MAIN --
-----------------------------
return Module