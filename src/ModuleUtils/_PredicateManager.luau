--!strict
--@author: crusherfire
--@date: 11/20/24
--[[@description:
	A manager for collecting predicates and firing events when new predicates are added or removed.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Trove = require(script.Parent._Trove)
local Signal = require(script.Parent._Signal)

-----------------------------
-- TYPES --
-----------------------------
-- For all of the properties/fields of an object made from this class.
type Predicate = (...any) -> (boolean, ...any?)

type fields = {
	_trove: Trove.TroveType,
	Signals: {
		PredicateAdded: Signal.GenericSignal,
		PredicateRemoved: Signal.GenericSignal,
		DefaultEvaluationChanged: Signal.GenericSignal,
		EvaluationModeChanged: Signal.GenericSignal,
	},
	_defaultEvaluation: boolean,
	_predicates: { [string]: Predicate },
	_evaluationMode: EvaluationMode
}

export type EvaluationMode = "AND" | "OR" | "NOR"

-----------------------------
-- VARIABLES --
-----------------------------
local PredicateManager = {}
local MT = {}
MT.__index = MT
export type PredicateManager = typeof(setmetatable({} :: fields, MT))

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

--[[
	<strong>defaultEvaluation</strong>: What the manager should return from :Evaluate() by default if there are no predicates. Default is true.
	<strong>evaluationMode</strong>: How predicates should be evaluated. Default is AND.
]]
function PredicateManager.new(defaultEvaluation: boolean?, evaluationMode: EvaluationMode?): PredicateManager
	local self = setmetatable({} :: fields, MT)
	
	self._trove = Trove.new()
	self.Signals = {
		PredicateAdded = self._trove:Construct(Signal),
		PredicateRemoved = self._trove:Construct(Signal),
		DefaultEvaluationChanged = self._trove:Construct(Signal),
		EvaluationModeChanged = self._trove:Construct(Signal),
	}
	self._defaultEvaluation = if defaultEvaluation ~= nil then defaultEvaluation else true
	self._predicates = {}
	
	self._evaluationMode = evaluationMode or "AND"
	
	return self
end

function PredicateManager:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object).__index == MT
end

--[[
	Evaluates all predicates based on the current evaluation mode.
	If there are no predicates, this will return the default value.
	<strong>AND</strong>: If any predicates return false, this will return false. All must pass.
	<strong>OR</strong>: If any predicate returns true, this will return true. At least one must pass.
	<strong>NOR</strong>: If all predicates return false, this will return true. None must pass.
]]
function MT.Evaluate(self: PredicateManager, ...: any?): (boolean, ...any?)
	local gotPredicate = false

	if self._evaluationMode == "AND" then
		-- AND logic - all must be true
		for _, predicate in pairs(self._predicates) do
			gotPredicate = true
			local success, msg = predicate(...)
			if not success then
				return false, msg
			end
		end
		return if gotPredicate then true else self._defaultEvaluation
	elseif self._evaluationMode == "OR" then
		-- OR logic - at least one must be true
		for _, predicate in pairs(self._predicates) do
			gotPredicate = true
			local success, msg = predicate(...)
			if success then
				return true, msg
			end
		end
		return if gotPredicate then false else self._defaultEvaluation
	elseif self._evaluationMode == "NOR" then
		-- NOR logic - all must be false
		for _, predicate in pairs(self._predicates) do
			gotPredicate = true
			local success, msg = predicate(...)
			if success then
				return false, msg
			end
		end
		return if gotPredicate then true else self._defaultEvaluation
	end

	error(`Invalid evaluation mode '{self._evaluationMode}'`)
end

function MT.SetEvaluationMode(self: PredicateManager, mode: EvaluationMode)
	if mode ~= self._evaluationMode then
		self._evaluationMode = mode
		self.Signals.EvaluationModeChanged:FireDefer()
	end
end

function MT.GetEvaluationMode(self: PredicateManager): EvaluationMode
	return self._evaluationMode
end

function MT.SetDefaultEvaluation(self: PredicateManager, defaultEvaluation: boolean)
	if defaultEvaluation ~= self._defaultEvaluation then
		self.Signals.DefaultEvaluationChanged:FireDefer()
	end
	self._defaultEvaluation = defaultEvaluation
end

function MT.GetDefaultEvaluation(self: PredicateManager): boolean
	return self._defaultEvaluation
end

--[[
	Sets a new predicate. Warns if overriding a predicate of the same identifier.
]]
function MT.AddPredicate(self: PredicateManager, identifier: any, isAble: Predicate)
	if self._predicates[identifier] then
		warn(`Overriding predicate with identifier: {identifier}`, debug.traceback())
	end
	self._predicates[identifier] = isAble
	self.Signals.PredicateAdded:FireDefer()
end

--[[
	Returns a copy of this manager's predicates.
]]
function MT.GetPredicates(self: PredicateManager): { [string]: Predicate }
	return table.clone(self._predicates)
end

--[[
	Removes the predicate with the given identifier, if any.
]]
function MT.RemovePredicate(self: PredicateManager, identifier: any)
	if not self._predicates[identifier] then
		return
	end
	self._predicates[identifier] = nil
	self.Signals.PredicateRemoved:FireDefer()
end

function MT.Destroy(self: PredicateManager)
	self._trove:Clean()
	table.clear(self._predicates)
end

-----------------------------
-- MAIN --
-----------------------------
return PredicateManager