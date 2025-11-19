--!strict
local ModuleUtils = require("@self/ModuleUtils")
export type SchedulerType = ModuleUtils.SchedulerType
export type SignalType<Func, ReturnVals...> = ModuleUtils.SignalType<Func, ReturnVals...>
export type Signal<ReturnVals...> = ModuleUtils.Signal<ReturnVals...>
export type GenericSignal = ModuleUtils.GenericSignal
export type SignalConnection = ModuleUtils.SignalConnection
export type TroveType = ModuleUtils.TroveType
export type OctreeType = ModuleUtils.OctreeType
export type OctreeNodeType = ModuleUtils.OctreeNodeType
export type TimerType = ModuleUtils.TimerType
export type ShakeType = ModuleUtils.ShakeType
export type ShakeProperties = ModuleUtils.ShakeProperties
export type CanPierceFunction = ModuleUtils.CanPierceFunction
export type Caster = ModuleUtils.Caster
export type FastCastBehavior = ModuleUtils.FastCastBehavior
export type CastTrajectory = ModuleUtils.CastTrajectory
export type CastStateInfo = ModuleUtils.CastStateInfo
export type CastRayInfo = ModuleUtils.CastRayInfo
export type ActiveCast = ModuleUtils.ActiveCast
export type CacheType = ModuleUtils.CacheType
type nlerpable = ModuleUtils.nlerpable
export type Spring<T = nlerpable> = ModuleUtils.Spring<T>
export type Quaternion = ModuleUtils.Quaternion
export type QuaternionSpring = ModuleUtils.QuaternionSpring
export type BE<Send...> = ModuleUtils.BE<Send...>
export type BF<Send..., Receive...> = ModuleUtils.BF<Send..., Receive...>
export type RE<Server..., Client...> = ModuleUtils.RE<Server...,  Client...>
export type RF<Send..., Receive...> = ModuleUtils.RF<Send..., Receive...>
export type AdjustmentPool = ModuleUtils.AdjustmentPool
export type AcceptedPoolValues = ModuleUtils.AcceptedPoolValues
export type PredicateManager = ModuleUtils.PredicateManager
export type TimeKeeper = ModuleUtils.TimeKeeper
export type CallbackManager = ModuleUtils.CallbackManager
export type Batcher = ModuleUtils.Batcher
export type BezierCurve = ModuleUtils.BezierCurve
export type DataCatalog<T> = ModuleUtils.DataCatalog<T>
export type RandomRotator = ModuleUtils.RandomRotator
export type RotationConfig = ModuleUtils.RotationConfig
export type Respawner = ModuleUtils.Respawner
export type Lottery = ModuleUtils.Lottery
export type LotteryTicket = ModuleUtils.LotteryTicket
export type LessSimpleZone<U, T...> = ModuleUtils.LessSimpleZone<U, T...>
export type Zone = ModuleUtils.Zone
export type BoxesZone = ModuleUtils.BoxesZone
export type PartsZone = ModuleUtils.PartsZone
export type ZoneQueryOptions = ModuleUtils.ZoneQueryOptions
export type ZoneBox = ModuleUtils.ZoneBox
export type Queue<T> = ModuleUtils.Queue<T>
export type Future<T...> = ModuleUtils.Future<T...>
export type RateLimiter = ModuleUtils.RateLimiter
export type DynamicOctree = ModuleUtils.DynamicOctree
export type ObjectPool = ModuleUtils.ObjectPool
export type LinearValue = ModuleUtils.LinearValue

local GlobalTypes = require("@self/GlobalTypes")
export type UniversalTimestamp = GlobalTypes.UniversalTimestamp
export type PlayerJoinData = GlobalTypes.PlayerJoinData
export type AgentParameters = GlobalTypes.AgentParameters
export type FollowPathOptions = GlobalTypes.FollowPathOptions
export type FollowPathResult = GlobalTypes.FollowPathResult

local FunctionUtils = require("@self/FunctionUtils")
export type Schema = FunctionUtils.Schema

return {
    FunctionUtils = FunctionUtils,
    ModuleUtils = ModuleUtils,
}