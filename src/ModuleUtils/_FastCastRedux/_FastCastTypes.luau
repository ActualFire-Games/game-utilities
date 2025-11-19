--!strict
-- ^ change to strict to crash studio c:

-- Defines all FC types.
-- Any script that requires this will have these types defined.

--[[
local TypeDefs = require(script.TypeDefinitions)
type CanPierceFunction = TypeDefs.CanPierceFunction
type GenericTable = TypeDefs.GenericTable
type Caster = TypeDefs.Caster
type FastCastBehavior = TypeDefs.FastCastBehavior
type CastTrajectory = TypeDefs.CastTrajectory
type CastStateInfo = TypeDefs.CastStateInfo
type CastRayInfo = TypeDefs.CastRayInfo
type ActiveCast = TypeDefs.ActiveCast
--]]
local Signal = require("../_Signal")

-- Represents the function to determine piercing.
export type CanPierceFunction = (ActiveCast, RaycastResult, Vector3) -> boolean

-- Represents any table.
export type GenericTable = {[any]: any}

-- Represents a Caster :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/caster/
export type Caster = {
	WorldRoot: WorldRoot,
	LengthChanged: Signal.SignalType<(activeCast: ActiveCast, lastPoint: Vector3, direction: Vector3, displacement: number, segmentVelocity: Vector3, cosmeticBulletObj: Instance?) -> (), (ActiveCast, Vector3, Vector3, number, Vector3, Instance?)>,
	RayHit: Signal.SignalType<(activeCast: ActiveCast, result: RaycastResult, segmentVelocity: Vector3, cosmeticBulletObj: Instance?) -> (), (ActiveCast, RaycastResult, Vector3, Instance?)>,
	RayPierced: Signal.SignalType<(activeCast: ActiveCast, result: RaycastResult, segmentVelocity: Vector3, cosmeticBulletObj: Instance?) -> (), (ActiveCast, RaycastResult, Vector3, Instance?)>,
	CastTerminating: Signal.SignalType<(activeCast: ActiveCast) -> (), (ActiveCast)>,
	Fire: (self: Caster, origin: Vector3, direction: Vector3, velocity: Vector3 | number, behavior: FastCastBehavior?) -> (ActiveCast)
}

-- Represents a FastCastBehavior :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/fcbehavior/
export type FastCastBehavior = {
	RaycastParams: RaycastParams?,
	MaxDistance: number,
	Acceleration: Vector3,
	HighFidelityBehavior: number,
	HighFidelitySegmentSize: number,
	SphereCastRadius: number?, -- A value that must be greater than 0 that will change the raycast into a spherecast.
	CosmeticBulletTemplate: Instance?,
	CosmeticBulletProvider: any, -- Intended to be a PartCache. Dictated via TypeMarshaller.
	CosmeticBulletContainer: Instance?,
	AutoIgnoreContainer: boolean,
	CanPierceFunction: CanPierceFunction?
}

-- Represents a CastTrajectory :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/casttrajectory/
export type CastTrajectory = {
	StartTime: number,
	EndTime: number,
	Origin: Vector3,
	InitialVelocity: Vector3,
	Acceleration: Vector3
}

-- Represents a CastStateInfo :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/caststateinfo/
export type CastStateInfo = {
	UpdateConnection: RBXScriptSignal,
	HighFidelityBehavior: number,
	HighFidelitySegmentSize: number,
	Paused: boolean,
	TotalRuntime: number,
	DistanceCovered: number,
	IsActivelySimulatingPierce: boolean,
	IsActivelyResimulating: boolean,
	CancelHighResCast: boolean,
	Trajectories: {[number]: CastTrajectory}
}

-- Represents a CastRayInfo :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/castrayinfo/
export type CastRayInfo = {
	Parameters: RaycastParams,
	WorldRoot: WorldRoot,
	MaxDistance: number,
	CosmeticBulletObject: Instance?,
	CanPierceCallback: CanPierceFunction,
	SphereRadius: number?
}

-- Represents an ActiveCast :: https://etithespirit.github.io/FastCastAPIDocs/fastcast-objects/activecast/
export type ActiveCast = {
	Caster: Caster,
	StateInfo: CastStateInfo,
	RayInfo: CastRayInfo,
	UserData: {[any]: any},
	
	GetPosition: (self: ActiveCast) -> (Vector3),
	SetVelocity: (self: ActiveCast, velocity: Vector3) -> (),
	SetAcceleration: (self: ActiveCast, acceleration: Vector3) -> (),
	SetPosition: (self: ActiveCast, position: Vector3) -> (),
	AddVelocity: (self: ActiveCast, velocity: Vector3) -> (),
	AddAcceleration: (self: ActiveCast, acceleration: Vector3) -> (),
	AddPosition: (self: ActiveCast, position: Vector3) -> (),
	Pause: (self: ActiveCast) -> (),
	Resume: (self: ActiveCast) -> (),
	Terminate: (self: ActiveCast) -> ()
}

return {}