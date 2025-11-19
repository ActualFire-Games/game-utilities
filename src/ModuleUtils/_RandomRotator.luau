--!strict
--@author: crusherfire
--@date: 4/25/25
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local FunctionUtils = require("../FunctionUtils")
local t = FunctionUtils.t

-----------------------------
-- TYPES --
-----------------------------

type Angles = {
	X: number,
	Y: number,
	Z: number
}

export type PhaseOffsets = {
	X: number,
	Y: number,
	Z: number
}

type fields = {
	_config: RotationConfigStrict,
	_time: number,
	_lastTime: number,
	_startTime: number,
	_initialAngles: Angles,
	_angles: Angles,
	_phase: PhaseOffsets
}

export type RotationConfig = {
	RNG: Random?,
	RotSpeedX: number?,
	RotSpeedY: number?,
	RotSpeedZ: number?,
	VariationFrequency: number?,
	VariationAmplitude: number?,
	VariationPhaseOffset: { X: number?, Y: number?, Z: number? }?, -- X & Z use sine and Y uses cosine
	Clock: ( () -> number )?
}

type RotationConfigStrict = {
	RNG: Random,
	RotSpeedX: number,
	RotSpeedY: number,
	RotSpeedZ: number,
	VariationFrequency: number,
	VariationAmplitude: number,
	VariationPhaseOffset: { X: number?, Y: number?, Z: number? },
	Clock: ( () -> number )
}

-----------------------------
-- VARIABLES --
-----------------------------
local RandomRotator = {}
local MT = {}
MT.__index = MT
export type RandomRotator = typeof(setmetatable({} :: fields, MT))

-- CONSTANTS --
local DEFAULT_CONFIG: RotationConfigStrict = {
	RNG = Random.new(tick()),
	RotSpeedX = 0.02,
	RotSpeedY = 0.02,
	RotSpeedZ = 0.02,
	VariationFrequency = 0.5,
	VariationAmplitude = 0.5,
	VariationPhaseOffset = {},
	Clock = os.clock
}
local TAU = math.pi * 2

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- CLASS FUNCTIONS --
-----------------------------

function RandomRotator.new(config: RotationConfig?): RandomRotator
	local self = setmetatable({} :: fields, MT) :: RandomRotator
	self._config = FunctionUtils.Table.reconcile(config or {}, DEFAULT_CONFIG)
	local config = self._config
	local rng = config.RNG
	local offsets = config.VariationPhaseOffset
	
	self._startTime = config.Clock()
	self._time = self._startTime
	self._lastTime = self._startTime
	self._initialAngles = {
		X = self._config.RNG:NextNumber(0, TAU),
		Y = self._config.RNG:NextNumber(0, TAU),
		Z = self._config.RNG:NextNumber(0, TAU),
	}
	self._angles = table.clone(self._initialAngles)
	self._phase = {
		X = offsets.X or rng:NextNumber(0, TAU),
		Y = offsets.Y or rng:NextNumber(0, TAU),
		Z = offsets.Z or rng:NextNumber(0, TAU),
	}
	
	return self
end

function RandomRotator:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object) == MT
end

-----------------------------
-- METHODS --
-----------------------------

@native
-- Advances internal time and returns next CFrame rotation
function MT.Update(self: RandomRotator): CFrame
	local cfg = self._config
	local now = cfg.Clock()
	local dt = now - self._lastTime
	self._lastTime = now
	self._time = self._time + dt

	local elapsed = self._time - self._startTime
	local vf, va = cfg.VariationFrequency, cfg.VariationAmplitude
	local randAmp = cfg.RNG:NextNumber(0.9, 1.1)

	-- per-axis variation
	local vx = math.sin(elapsed * vf + self._phase.X) * va * randAmp
	local vy = math.cos(elapsed * vf + self._phase.Y) * va * randAmp
	local vz = math.sin(elapsed * vf + self._phase.Z) * va * randAmp

	self._angles.X += (cfg.RotSpeedX + vx) * dt
	self._angles.Y += (cfg.RotSpeedY + vy) * dt
	self._angles.Z += (cfg.RotSpeedZ + vz) * dt

	return CFrame.Angles(self._angles.X, self._angles.Y, self._angles.Z)
end

-- Reset timer, angles, and regenerate phases if not user-defined
function MT.Reset(self: RandomRotator)
	local cfg = self._config
	local rng = cfg.RNG

	self._startTime = cfg.Clock()
	self._lastTime = self._startTime
	self._time = self._startTime

	-- reseed angles
	self._angles.X = rng:NextNumber(0, TAU)
	self._angles.Y = rng:NextNumber(0, TAU)
	self._angles.Z = rng:NextNumber(0, TAU)
	self._initialAngles = table.clone(self._angles)

	-- regenerate phase offsets if not fixed by config
	local offsets = cfg.VariationPhaseOffset
	self._phase.X = offsets.X or rng:NextNumber(0, TAU)
	self._phase.Y = offsets.Y or rng:NextNumber(0, TAU)
	self._phase.Z = offsets.Z or rng:NextNumber(0, TAU)
end

-----------------------------
-- SETTERS --
-----------------------------

-----------------------------
-- GETTERS --
-----------------------------

function MT.GetRotationAt(self: RandomRotator, timestamp: number): CFrame
	local cfg = self._config
	local elapsed = math.max(0, timestamp - self._startTime)

	local vf, va = cfg.VariationFrequency, cfg.VariationAmplitude
	local vx = math.sin(elapsed * vf + self._phase.X) * va
	local vy = math.cos(elapsed * vf + self._phase.Y) * va
	local vz = math.sin(elapsed * vf + self._phase.Z) * va

	local ax = self._initialAngles.X + (cfg.RotSpeedX + vx) * elapsed
	local ay = self._initialAngles.Y + (cfg.RotSpeedY + vy) * elapsed
	local az = self._initialAngles.Z + (cfg.RotSpeedZ + vz) * elapsed

	return CFrame.Angles(ax, ay, az)
end

-----------------------------
-- CLEANUP --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return RandomRotator