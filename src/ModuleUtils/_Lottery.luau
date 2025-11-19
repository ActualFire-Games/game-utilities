--!strict
--@author: crusherfire
--@date: 5/12/25
--[[@description:
	Random lottery pulling of identifiers with weights.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local t = require("../FunctionUtils/_t")

-----------------------------
-- TYPES --
-----------------------------
-- For all of the properties/fields of an object made from this class.
type fields = {
	_tickets: { LotteryTicket },
	_totalWeightCached: number?,
	_rng: Random,
}

export type LotteryTicket = {
	Identifier: any,
	Weight: number,
	[string]: any -- if you wish to store anything else associated with the ticket
}

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT
export type Lottery = typeof(setmetatable({} :: fields, MT))

-- Use a shared RNG seeded by current time
local RNG = Random.new(tick())

-----------------------------
-- CLASS FUNCTIONS --
-----------------------------

function Module.new(tickets: { LotteryTicket }?, rng: Random?): Lottery
	local self = setmetatable({} :: fields, MT) :: Lottery
	self._tickets = tickets or {}
	self._rng = rng or RNG
	return self
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")
	return getmetatable(object) == MT
end

-----------------------------
-- METHODS --
-----------------------------

-- Adds a lottery ticket with an associated positive weight to the pool.
function MT.AddTicket(self: Lottery, identifier: any, weight: number)
	assert(typeof(weight) == "number" and weight > 0, "Lottery:AddTicket expected weight to be a positive number")
	local ticket: LotteryTicket = {
		Identifier = identifier,
		Weight = weight
	}
	
	table.insert(self._tickets, ticket)
	self._totalWeightCached = nil -- reset cache
end

-- Draws a random ticket based on weights, without removing it from the pool.
-- Returns the drawn ticket.
function MT.DrawTicket(self: Lottery): LotteryTicket
	assert(#self._tickets > 0, "Lottery:DrawTicket called on empty ticket pool")

	local totalWeight = self._totalWeightCached or 0
	if not self._totalWeightCached then
		for _, ticket in ipairs(self._tickets) do
			totalWeight += ticket.Weight
		end
	end
	self._totalWeightCached = totalWeight
	
	local pick = self._rng:NextInteger(0, totalWeight - 1) -- Exclusive upper bound
	local cumulative = 0

	for _, ticket in ipairs(self._tickets) do
		cumulative += ticket.Weight
		if pick < cumulative then
			return ticket
		end
	end

	-- Fallback
	return self._tickets[#self._tickets]
end

function MT.GetTickets(self: Lottery): { LotteryTicket }
	return table.clone(self._tickets)
end

-----------------------------
-- CLEANUP / MAIN --
-----------------------------
return Module
