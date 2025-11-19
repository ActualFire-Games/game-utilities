--!strict
--@author: crusherfire
--@date: 5/30/25
--[[@description:
	Allows tracking of rate limits for different web request APIs.
	Give it rate limit information (when refreshed and how to calculate the total).
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local FunctionUtils = require("../FunctionUtils")
local t = FunctionUtils.t
local Signal = require("./_Signal")
local Trove = require("./_Trove")
local Future = require("./_Future")

-----------------------------
-- TYPES --
-----------------------------
-- For all of the properties/fields of an object made from this class.
type fields = {
	_trove: Trove.TroveType,
	_userData: { [any]: any },
	_params: RateLimiterParams,
	
	_availableTokens: number,
	_maxTokens: number,
	_lastRecalculationTime: number,
	
	Signals: {
		TokensAdded: Signal.SignalType<(added: number, tokensAvailable: number) -> (), (number, number)>,
		TokensRemoved: Signal.SignalType<(removed: number, tokensAvailable: number) -> (), (number, number)>,
		LimitChanged: Signal.SignalType<(maxLimit: number) -> (), (number)>,
	}
}

export type RateLimiterParams = {
	CalculateMaxLimit: () -> number,
	RefreshIntervalInSeconds: number,
	RecalculationTriggers: { any } -- signals to notify the limiter of when to CalculateLimit()
}

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT
export type RateLimiter = typeof(setmetatable({} :: fields, MT))

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- CLASS FUNCTIONS --
-----------------------------

function Module.new(params: RateLimiterParams): RateLimiter
	local self = setmetatable({} :: fields, MT) :: RateLimiter
	self._trove = Trove.new()
	self._userData = {}
	self._params = params
	
	self._availableTokens = params.CalculateMaxLimit()
	self._maxTokens = self._availableTokens
	self._lastRecalculationTime = os.clock()
	
	self.Signals = {
		TokensAdded = self._trove:Construct(Signal),
		TokensRemoved = self._trove:Construct(Signal),
		LimitChanged = self._trove:Construct(Signal),
	}
	
	for _, signal in params.RecalculationTriggers do
		self._trove:Connect(signal, function()
			self:_RecalculateLimit()
		end)
	end
	
	return self
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object) == MT
end

-----------------------------
-- METHODS --
-----------------------------

function MT.ConsumeToken(self: RateLimiter, tokens: number?): boolean
	local tokens = tokens or 1
	assert(t.number(tokens) and tokens > 0, "invalid tokens")

	if tokens <= self._availableTokens then
		self._availableTokens -= tokens
		self.Signals.TokensRemoved:FireDefer(tokens, self._availableTokens)
		
		local thread
		thread = self._trove:Add(task.delay(self._params.RefreshIntervalInSeconds, function()
			local newMax = self._params.CalculateMaxLimit()
			self._maxTokens = newMax

			local oldAvailable = self._availableTokens
			self._availableTokens = math.clamp(self._availableTokens + 1, 0, newMax)
			local added = self._availableTokens - oldAvailable

			if added > 0 then
				self.Signals.TokensAdded:FireDefer(added, self._availableTokens)
			end
			
			self._trove:Remove(thread)
		end))

		return true
	end

	return false
end

-- Waits for the token amount or immediately returns if the tokens are available.
function MT.WaitForToken(self: RateLimiter, tokens: number?)
	local tokens = tokens or 1
	while not self:CanConsume(tokens) do
		local traceback = debug.traceback()
		local thread = task.delay(self._params.RefreshIntervalInSeconds * 2, function()
			warn(`:WaitForToken() is taking a really long time!\n`, traceback)
		end)
		self._trove:Add(thread)
		self.Signals.TokensAdded:Wait()
		self._trove:Remove(thread)
	end
end

-- Waits for the token amount or immediately executes the future if tokens are available.
function MT.WaitForTokenFuture(self: RateLimiter, tokens: number?)
	tokens = tokens or 1
	return Future.new(function(tokens)
		self:WaitForToken(tokens)
	end, tokens)
end

function MT._RecalculateLimit(self: RateLimiter)
	local oldMax = self._maxTokens
	local oldAvailable = self._availableTokens

	local newMax = self._params.CalculateMaxLimit()
	local consumed = oldMax - oldAvailable

	self._maxTokens = newMax
	self._availableTokens = math.max(0, newMax - consumed)

	self._lastRecalculationTime = os.clock()
	self.Signals.LimitChanged:FireDefer(newMax)

	local delta = self._availableTokens - oldAvailable
	if delta > 0 then
		self.Signals.TokensAdded:FireDefer(delta, self._availableTokens)
	elseif delta < 0 then
		self.Signals.TokensRemoved:FireDefer(-delta, self._availableTokens)
	end
end

-----------------------------
-- SETTERS --
-----------------------------

-----------------------------
-- GETTERS --
-----------------------------

function MT.CanConsume(self: RateLimiter, tokens: number?): boolean
	local tokens = tokens or 1
	return self._availableTokens >= tokens
end

function MT.GetMaxTokens(self: RateLimiter): number
	return self._maxTokens
end

function MT.GetAvailableTokens(self: RateLimiter): number
	return self._availableTokens
end

function MT.GetTrove(self: RateLimiter): Trove.TroveType
	return self._trove
end

function MT.GetUserData(self: RateLimiter): { [any]: any }
	return self._userData
end

-----------------------------
-- CLEANUP --
-----------------------------

function MT.Destroy(self: RateLimiter)
	self._trove:Clean()
end

-----------------------------
-- MAIN --
-----------------------------
return Module