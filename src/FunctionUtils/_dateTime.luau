--!strict
--@author: crusherfire
--@date: 6/3/25
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------

-----------------------------
-- TYPES --
-----------------------------
local GlobalTypes = require("../GlobalTypes")

export type UniversalTimestamp = GlobalTypes.UniversalTimestamp

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

function Module.getOneHourInSeconds(): number
	return 3600
end

function Module.getOneDayInSeconds(): number
	return 86400
end

-- Converts a UniversalTimestamp into a DateTime object
function Module.fromTimestamp(timestamp: UniversalTimestamp): DateTime
	return DateTime.fromUniversalTime(
		timestamp.Year,
		timestamp.Month,
		timestamp.Day,
		timestamp.Hour,
		timestamp.Minute,
		timestamp.Second,
		timestamp.Millisecond
	)
end

-- Returns the number of whole seconds between two DateTime values
function Module.secondsBetween(a: DateTime, b: DateTime): number
	return math.abs(a.UnixTimestamp - b.UnixTimestamp)
end

-- Returns the number of full days between two DateTime values
function Module.daysBetween(a: DateTime, b: DateTime): number
	return math.floor(Module.secondsBetween(a, b) / 86400)
end

-- Returns a new DateTime offset by the given number of seconds
function Module.offsetBySeconds(dateTime: DateTime, seconds: number): DateTime
	return DateTime.fromUnixTimestamp(dateTime.UnixTimestamp + seconds)
end

function Module.now(): DateTime
	return DateTime.now()
end

-- Returns the current UniversalTimestamp
function Module.nowTimestamp(): UniversalTimestamp
	return DateTime.now():ToUniversalTime()
end

-- Returns the elapsed seconds since a given DateTime
function Module.elapsedSince(start: DateTime): number
	return DateTime.now().UnixTimestamp - start.UnixTimestamp
end

-- Returns true if the given duration (in seconds) has passed since start
function Module.hasElapsed(start: DateTime, durationSeconds: number): boolean
	return Module.elapsedSince(start) >= durationSeconds
end

-- Returns true if both timestamps fall on the same calendar day
function Module.isSameDay(a: DateTime, b: DateTime): boolean
	local aUtc = a:ToUniversalTime()
	local bUtc = b:ToUniversalTime()

	return aUtc.Year == bUtc.Year
		and aUtc.Month == bUtc.Month
		and aUtc.Day == bUtc.Day
end

-- Rounds down to the start of the day (00:00:00) in UTC
function Module.floorToStartOfDay(dateTime: DateTime): DateTime
	local utc = dateTime:ToUniversalTime()
	return DateTime.fromUniversalTime(utc.Year, utc.Month, utc.Day, 0, 0, 0)
end

-- Rounds down to the start of the hour in UTC
function Module.floorToStartOfHour(dateTime: DateTime): DateTime
	local utc = dateTime:ToUniversalTime()
	return DateTime.fromUniversalTime(utc.Year, utc.Month, utc.Day, utc.Hour, 0, 0)
end

-----------------------------
-- MAIN --
-----------------------------
return Module