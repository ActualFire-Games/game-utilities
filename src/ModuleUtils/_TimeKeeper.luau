--!strict
--@author: crusherfire
--@date: 10/8/24
--[[@description:
	Provides signals that fire when the year, month, day, hour, and minute changes.
]]
-----------------------------
-- SERVICES --
-----------------------------
local RunService = game:GetService("RunService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Signal = require(script.Parent._Signal)
local Trove = require(script.Parent._Trove)
local FunctionUtils = require("../FunctionUtils")

-----------------------------
-- TYPES --
-----------------------------
local GlobalTypes = require("../GlobalTypes")
-- This is for all of the properties of an object made from this class for type annotation purposes.
type self = {
	_trove: Trove.TroveType,
	_previousTimestamp: DateTime,
	_startDateTime: DateTime,
	
	Signals: {
		-- Fires when year, month, day, hour, minute, or second changes.
		TimeChanged: Signal.SignalType<(previous: UniversalTimestamp, current: UniversalTimestamp) -> (), (UniversalTimestamp, UniversalTimestamp)>,
		
		YearChanged: Signal.SignalType<(previous: number, current: number) -> (), (number, number)>,
		MonthChanged: Signal.SignalType<(previous: number, current: number) -> (), (number, number)>,
		DayChanged: Signal.SignalType<(previous: number, current: number) -> (), (number, number)>,
		HourChanged: Signal.SignalType<(previous: number, current: number) -> (), (number, number)>,
		MinuteChanged: Signal.SignalType<(previous: number, current: number) -> (), (number, number)>,
		SecondChanged: Signal.SignalType<(previous: number, current: number) -> (), (number, number)>,
	}
}

export type UniversalTimestamp = GlobalTypes.UniversalTimestamp

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT
export type TimeKeeper = typeof(setmetatable({} :: self, MT))

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local dateTimeNow = DateTime.now

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates and returns a TimeKeeper.
-- Optionally provide your own starting point.
function Module.new(startingPoint: DateTime?): TimeKeeper
	local self = setmetatable({} :: self, MT)
	self._trove = Trove.new()
	local timeNow = dateTimeNow()
	self._previousTimestamp = timeNow
	self._startDateTime = (startingPoint or timeNow)
	
	self.Signals = {
		TimeChanged = self._trove:Construct(Signal),
		YearChanged = self._trove:Construct(Signal),
		MonthChanged = self._trove:Construct(Signal),
		DayChanged = self._trove:Construct(Signal),
		HourChanged = self._trove:Construct(Signal),
		MinuteChanged = self._trove:Construct(Signal),
		SecondChanged = self._trove:Construct(Signal),
	}
	
	self._trove:Connect(RunService.Heartbeat, function()
		local now = dateTimeNow()
		local currentTimestamp = now:ToUniversalTime()
		local previousTimestamp = self._previousTimestamp:ToUniversalTime()
		local changed = false

		if previousTimestamp.Year ~= currentTimestamp.Year then
			changed = true
			self.Signals.YearChanged:Fire(previousTimestamp.Year, currentTimestamp.Year)
		end

		if previousTimestamp.Month ~= currentTimestamp.Month then
			changed = true
			self.Signals.MonthChanged:Fire(previousTimestamp.Month, currentTimestamp.Month)
		end

		if previousTimestamp.Day ~= currentTimestamp.Day then
			changed = true
			self.Signals.DayChanged:Fire(previousTimestamp.Day, currentTimestamp.Day)
		end

		if previousTimestamp.Hour ~= currentTimestamp.Hour then
			changed = true
			self.Signals.HourChanged:Fire(previousTimestamp.Hour, currentTimestamp.Hour)
		end

		if previousTimestamp.Minute ~= currentTimestamp.Minute then
			changed = true
			self.Signals.MinuteChanged:Fire(previousTimestamp.Minute, currentTimestamp.Minute)
		end
		
		if previousTimestamp.Second ~= currentTimestamp.Second then
			changed = true
			self.Signals.SecondChanged:Fire(previousTimestamp.Second, currentTimestamp.Second)
		end
		
		if changed then
			self.Signals.TimeChanged:Fire(previousTimestamp, currentTimestamp)
		end

		self._previousTimestamp = now
	end)

	return self
end

-- Creates and returns a TimeKeeper with a starting point defined by the timestamp.
function Module.fromTimestamp(startingTimestamp: UniversalTimestamp): TimeKeeper
	return Module.new(FunctionUtils.DateTime.fromTimestamp(startingTimestamp))
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object).__index == MT
end

-- Updates the start timestamp to dateTime.
-- This will reset the signals to calculate when seconds/minutes/etc changes from this new start time.
function MT.SetStartTime(self: TimeKeeper, dateTime: DateTime)
	self._startDateTime = dateTime
	self._previousTimestamp = dateTime
end

-- Updates the start timestamp to now.
-- Shorthand for <code>:SetStartTime(DateTime.now())</code>
function MT.AdvanceToNow(self: TimeKeeper)
	self:SetStartTime(dateTimeNow())
end

-- Checks if the amount of seconds that has elapsed since the start time is greater than the window duration.
function MT.HasWindowElapsed(self: TimeKeeper, windowDurationInSeconds: number): boolean
	return self:GetElapsedSeconds() >= windowDurationInSeconds
end

-- Get the amount of time that has passed since the last recorded start timestamp.
function MT.GetElapsedSeconds(self: TimeKeeper): number
	return dateTimeNow().UnixTimestamp - self._startDateTime.UnixTimestamp
end

-- Return the last recorded start DateTime for this object.
function MT.GetStartDateTime(self: TimeKeeper): DateTime
	return self._startDateTime
end

-- Get the math.floored amount of days elapsed since the start timestamp.
function MT.GetDaysSinceStart(self: TimeKeeper): number
	return math.floor(self:GetElapsedSeconds() / 86400)
end

-- Returns the current global timestamp.
function MT.GetCurrentTime(self: TimeKeeper): UniversalTimestamp
	return dateTimeNow():ToUniversalTime()
end

--[[
	Returns the current unix timestamp.
]]
function MT.GetUnixTimestamp(self: TimeKeeper, type: "seconds" | "milliseconds")
	return if type == "seconds" then dateTimeNow().UnixTimestamp else dateTimeNow().UnixTimestampMillis
end

--[[
	Returns the unix timestamp of the starting time for this time keeper.
]]
function MT.GetStartUnixTimestamp(self: TimeKeeper, type: "seconds" | "milliseconds")
	return if type == "seconds" then self._startDateTime.UnixTimestamp else self._startDateTime.UnixTimestampMillis
end

-- Gets the current global time offset by secondsOffset
function MT.GetTimeWithOffset(self: TimeKeeper, secondsOffset: number): UniversalTimestamp
	local currentTime = dateTimeNow().UnixTimestamp
	local correctedTime = currentTime + secondsOffset
	
	return DateTime.fromUnixTimestamp(correctedTime):ToUniversalTime()
end

function MT.Destroy(self: TimeKeeper)
	self._trove:Clean()
end

-----------------------------
-- MAIN --
-----------------------------
return Module