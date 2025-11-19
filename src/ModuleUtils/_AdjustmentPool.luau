--!strict
--@author: crusherfire
--@date: 11/1/24
--[[@description:
	Pools together different multipliers & offsets and can calculate the proper value after all offsets & multipliers are applied.
	This is VERY useful for multiple different scripts that attempt to modify the same property.
	
	For example, if there is a module that modifies walk speed for spriting & another that modifies walk speed for crouching,
	how can we pool their modifiers together and get a final result?
	
	Another example: a module that modifies camera FOV for guns & a module that modifies camera FOV when sprinting.
	We want to pool the modifiers together so we don't have either module interfering with each other!
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local FunctionUtils = require("../FunctionUtils")
local Trove = require(script.Parent._Trove)
local Signal = require(script.Parent._Signal)

-----------------------------
-- TYPES --
-----------------------------
type ModifierType = "O" | "M"
type ModifierEntry = { V: any, P: number, T: ModifierType }
type fields = {
	_trove: Trove.TroveType,
	Signals: {
		Changed: Signal.SignalType<() -> (), ()>, -- Fired when a modifier is added/removed or the initial value is changed.
		Destroying: Signal.SignalType<() -> (), ()> -- Fired right before the pool is destroyed
	},
	_identifier: string,
	_initial: AcceptedValues,
	_modifiers: { [any]: ModifierEntry }, -- V is value, P is priority, T is type
	_cachedResultMixed: any?, -- Result of offsets & multipliers mixed based on priority
	_cachedResultOffsetsFirst: any?, -- Result of offsets first and then multipliers based on priority
	_cachedResultsMultipliersFirst: any?, -- Result of multiplier first and then offsets based on priority
}

-----------------------------
-- VARIABLES --
-----------------------------
local AdjustmentPool = {}
local MT = {}
MT.__index = MT
export type AdjustmentPool = typeof(setmetatable({} :: fields, MT))
export type AcceptedValues = number | Vector3 | Vector2

local objectCache: { AdjustmentPool } = {}

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates and returns a new <code>AdjustmentPool</code>, or returns one if it already exists.
-- <strong>identifier</strong>: An optional ID for this pool. Further calls to <code>.new()</code> with the same ID will return the same pool.
-- <strong>starting</strong>: The initial value that all modifiers will be calculated upon. Serves as the basis for the pooled adjustments.
-- If not provided, the default initial value is 0.
function AdjustmentPool.new(identifier: string?, initial: AcceptedValues?): AdjustmentPool
	local whatType = typeof(initial)
	assert(whatType == "number" or whatType == "Vector3" or whatType == "Vector2" or whatType == "nil", "Invalid starting value.")
	if identifier then
		local self = AdjustmentPool:GetObject(identifier)
		if self then
			return self
		end
	end
	
	local identifier: string = identifier :: any
	if not identifier then
		repeat
			identifier = FunctionUtils.Base64.random()
		until not AdjustmentPool:GetObject(identifier :: any)
	end
	
	local myTrove = Trove.new()
	local self: fields = {
		_trove = myTrove,
		Signals = {
			Changed = myTrove:Construct(Signal),
			Destroying = myTrove:Construct(Signal)
		},
		_identifier = identifier,
		_initial = initial or 0,
		_modifiers = {},
	}
	
	setmetatable(self, MT)
	table.insert(objectCache, self)
	return self
end

function AdjustmentPool:GetObject(identifier: string): AdjustmentPool?
	for _, obj in ipairs(objectCache) do
		if obj:Identifier() == identifier then
			return obj
		end
	end
	return
end

function AdjustmentPool:BelongsToClass(object: any): boolean
	assert(typeof(object) == "table", "Expected table for object!")
	
	local mt = getmetatable(object)
	return mt ~= nil and mt.__index == MT
end

function MT.Identifier(self: AdjustmentPool): string
	return self._identifier
end

--[[
	Observes whenever the pooled total changes/pool is destroyed.
	Total is calculated by the given <code>mode</code>, default is <code>Mixed</code>.
]]
function MT.Observe(
	self: AdjustmentPool,
	callback: (newValue: AcceptedValues) -> ( () -> () )?,
	guard: ( (AcceptedValues) -> boolean )?,
	mode: ("Mixed" | "OffsetsFirst" | "SummedMultipliers")?
)
	local valueGuard: any = guard or function(_v)
		return true
	end

	local cleanupFn: (() -> ())?
	local changeId = 0
	local changedConn: Signal.SignalConnection
	local destroyConn: Signal.SignalConnection

	local function evaluate(): AcceptedValues
		if mode == "OffsetsFirst" then
			return self:EvaluateTotalByOffsetsFirst()
		elseif mode == "SummedMultipliers" then
			return self:EvaluateTotalBySummedMultipliers()
		else
			return self:EvaluateTotalMixed()
		end
	end

	local function onChanged()
		if cleanupFn then
			task.spawn(cleanupFn)
			cleanupFn = nil
		end

		changeId += 1
		local thisId = changeId
		local newValue = evaluate()
		if not valueGuard(newValue) then
			return
		end

		task.spawn(function()
			local success, result = xpcall(function()
				return callback(newValue)
			end, function(err)
				return `{err}\n{debug.traceback()}`
			end)
			if success then
				if
					typeof(result) == "function"
					and changedConn.Connected
					and thisId == changeId
				then
					cleanupFn = result
				elseif typeof(result) == "function" then
					task.spawn(result)
				end
			else
				warn(result)
			end
		end)
	end

	local function doTeardown()
		if changedConn.Connected then
			changedConn:Disconnect()
		end
		if destroyConn.Connected then
			destroyConn:Disconnect()
		end
		if cleanupFn then
			task.spawn(cleanupFn)
			cleanupFn = nil
		end
	end

	changedConn = self.Signals.Changed:Connect(onChanged)
	destroyConn = self.Signals.Destroying:Connect(doTeardown)

	task.defer(onChanged)

	return doTeardown
end

-- Changes the initial value.
function MT.ChangeInitial(self: AdjustmentPool, new: AcceptedValues)
	self._initial = new
	self:_ClearCachedResults()
end

-- An all in one function of AddMultiplier or AddOffset
function MT.AddModifier(self: AdjustmentPool, identifier: any, value: any, modifierType: ModifierType, priority: number?)
	self._modifiers[identifier] = { V = value, P = priority or 1, T = modifierType }
	self:_ClearCachedResults()
end

-- Gets the value of the modifier (if it exists)
function MT.GetModifierValue(self: AdjustmentPool, identifier: any): any
	return if self._modifiers[identifier] then self._modifiers[identifier].V else nil
end

-- Gets the type of the modifier (if it exists)
function MT.GetModifierType(self: AdjustmentPool, identifier: any): ModifierType?
	return if self._modifiers[identifier] then self._modifiers[identifier].T else nil
end

function MT.RemoveModifier(self: AdjustmentPool, identifier: any)
	self._modifiers[identifier] = nil
	self:_ClearCachedResults()
end

function MT.AddMultiplier(self: AdjustmentPool, identifier: any, value: any, priority: number?)
	self._modifiers[identifier] = { V = value, P = priority or 1, T = "M" }
	self:_ClearCachedResults()
end

function MT.AddOffset(self: AdjustmentPool, identifier: any, value: any, priority: number?)
	self._modifiers[identifier] = { V = value, P = priority or 1, T = "O" }
	self:_ClearCachedResults()
end

function MT.GetInitial(self: AdjustmentPool): AcceptedValues
	return self._initial
end

--[[
	Evaluates the total by multiplying against the initial value and then adding offsets afterwards.
]]
function MT.EvaluateTotalByOffsetsFirst(self: AdjustmentPool): any
	if self._cachedResultOffsetsFirst then
		return self._cachedResultOffsetsFirst
	end

	local modifiers = FunctionUtils.Table.toArray(self._modifiers)
	table.sort(modifiers, function(a, b)
		if a.T == b.T then
			return a.P > b.P
		end
		return a.T == "O"
	end)

	local result = self._initial
	for _, entry in ipairs(modifiers) do
		result = if entry.T == "O" then result + entry.V else result * entry.V
	end

	self._cachedResultOffsetsFirst = result
	return result
end

--[[
	Evaluates the total by multiplying & adding based on priority.
]]
function MT.EvaluateTotalMixed(self: AdjustmentPool): any
	if self._cachedResultMixed then
		return self._cachedResultMixed
	end

	local modifiers = FunctionUtils.Table.toArray(self._modifiers)
	table.sort(modifiers, function(a, b)
		return a.P > b.P
	end)

	local result = self._initial
	for _, entry in ipairs(modifiers) do
		result = if entry.T == "M" then result * entry.V else result + entry.V
	end

	self._cachedResultMixed = result
	return result
end

--[[
	Evaluates the total by applying all offsets first, summing all multipliers, then multiplying once.
]]
function MT.EvaluateTotalBySummedMultipliers(self: AdjustmentPool): any
	local offsetSum: any = self._initial
	local multiplierSum = 0
	local hasMultipliers = false

	for _, entry in self._modifiers do
		if entry.T == "O" then
			offsetSum += entry.V
		elseif entry.T == "M" then
			multiplierSum += entry.V
			hasMultipliers = true
		end
	end

	if not hasMultipliers then
		multiplierSum = 1
	end

	return offsetSum * multiplierSum
end

-- Call when a modifier is changed or the initial value is changed.
function MT._ClearCachedResults(self: AdjustmentPool)
	self._cachedResultOffsetsFirst = nil
	self._cachedResultsMultipliersFirst = nil
	self._cachedResultMixed = nil
	self.Signals.Changed:Fire()
end

function MT.Destroy(self: AdjustmentPool)
	self.Signals.Destroying:Fire()
	self._trove:Clean()
	local i = table.find(objectCache, self)
	if i then
		table.remove(objectCache, i)
	end
end

-----------------------------
-- MAIN --
-----------------------------
return AdjustmentPool