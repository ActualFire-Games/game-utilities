--!strict
local GlobalTypes = require("./GlobalTypes")
export type UniversalTimestamp = GlobalTypes.UniversalTimestamp

local _Scheduler = require(script._Scheduler)
export type SchedulerType = _Scheduler.SchedulerType

local _Signal = require(script._Signal)
-- Func is the function passed to :Once() or :Connect(). ReturnVals is the data returned from :Wait() or passed to :Fire()
-- The args in Func should match ReturnVals!
export type SignalType<Func, ReturnVals...> = _Signal.SignalType<Func, ReturnVals...>
-- If you don't want to bother defining argument names:
export type Signal<ReturnVals...> = _Signal.Signal<ReturnVals...>
export type GenericSignal = _Signal.GenericSignal
export type SignalConnection = _Signal.SignalConnection

local _Trove = require(script._Trove)
export type TroveType = _Trove.TroveType

local _Octree = require(script._Octree)
export type OctreeType = _Octree.OctreeType
export type OctreeNodeType = _Octree.OctreeNodeType

local _Timer = require(script._Timer)
export type TimerType = _Timer.TimerType

local _Shake = require(script._Shake)
export type ShakeType = _Shake.ShakeType
export type ShakeProperties = _Shake.ShakeProperties

local _FastCastRedux = require(script._FastCastRedux)
local FastCastTypes = require(script._FastCastRedux._FastCastTypes)
export type CanPierceFunction = FastCastTypes.CanPierceFunction
export type Caster = FastCastTypes.Caster
export type FastCastBehavior = FastCastTypes.FastCastBehavior
export type CastTrajectory = FastCastTypes.CastTrajectory
export type CastStateInfo = FastCastTypes.CastStateInfo
export type CastRayInfo = FastCastTypes.CastRayInfo
export type ActiveCast = FastCastTypes.ActiveCast

local _Cache = require(script._Cache)
export type CacheType = _Cache.CacheType

local _Spring = require(script._Spring)
export type nlerpable = _Spring.nlerpable
export type Spring<T = nlerpable> = _Spring.Spring<T>

local _Quaternion = require(script._Quaternion)
export type Quaternion = _Quaternion.Quaternion

local _QuaternionSpring = require(script._QuaternionSpring)
export type QuaternionSpring = _QuaternionSpring.QuaternionSpring

local _TypedBindable = require(script._TypedBindable)
export type BE<Send...> = _TypedBindable.Event<Send...>
export type BF<Send..., Receive...> = _TypedBindable.Function<Send..., Receive...>

local _TypedRemote = require(script._TypedRemote)
export type RE<Server..., Client...> = _TypedRemote.Event<Server...,  Client...>
export type RF<Send..., Receive...> = _TypedRemote.Function<Send..., Receive...>

local _AdjustmentPool = require(script._AdjustmentPool)
export type AdjustmentPool = _AdjustmentPool.AdjustmentPool
export type AcceptedPoolValues = _AdjustmentPool.AcceptedValues

local _PredicateManager = require(script._PredicateManager)
export type PredicateManager = _PredicateManager.PredicateManager

local _TimeKeeper = require(script._TimeKeeper)
export type TimeKeeper = _TimeKeeper.TimeKeeper

local _CallbackManager = require(script._CallbackManager)
export type CallbackManager = _CallbackManager.CallbackManager

local _Batcher = require(script._Batcher)
export type Batcher = _Batcher.Batcher

local _Bezier = require(script._Bezier)
export type BezierCurve = _Bezier.BezierCurve

local _DataCatalog = require(script._DataCatalog)
export type DataCatalog<T> = _DataCatalog.DataCatalog<T>

local _RandomRotator = require(script._RandomRotator)
export type RandomRotator = _RandomRotator.RandomRotator
export type RotationConfig = _RandomRotator.RotationConfig

local _Respawner = require(script._Respawner)
export type Respawner = _Respawner.Respawner

local _Lottery = require(script._Lottery)
export type Lottery = _Lottery.Lottery
export type LotteryTicket = _Lottery.LotteryTicket

local _Zone = require(script._Zone)
export type LessSimpleZone<U, T...> = _Zone.LessSimpleZone<U, T...>
export type Zone = _Zone.Zone
export type BoxesZone = _Zone.BoxesZone
export type PartsZone = _Zone.PartsZone
export type ZoneQueryOptions = _Zone.QueryOptions
export type ZoneBox = _Zone.Box

local _Queue = require(script._Queue)
export type Queue<T> = _Queue.Queue<T>

local _Future = require(script._Future) -- replacement for promises
export type Future<T...> = _Future.Future<T...>

local _RateLimiter = require(script._RateLimiter)
export type RateLimiter = _RateLimiter.RateLimiter

local _DynamicOctree = require(script._DynamicOctree)
export type DynamicOctree = _DynamicOctree.DynamicOctree

local _ObjectPool = require(script._ObjectPool)
export type ObjectPool = _ObjectPool.ObjectPool

local _LinearValue = require(script._LinearValue)
export type LinearValue = _LinearValue.LinearValue

return {
	Scheduler = _Scheduler,
	Signal = _Signal,
	Trove = _Trove,
	Zone = _Zone,
	Octree = _Octree,
	Timer = _Timer,
	Shake = _Shake,
	FastCast = _FastCastRedux,
	Cache = _Cache,
	Spring = _Spring,
	Quaternion = _Quaternion,
	QuaternionSpring = _QuaternionSpring,
	TypedRemote = _TypedRemote,
	TypedBindable = _TypedBindable,
	PredicateManager = _PredicateManager,
	CallbackManager = _CallbackManager,
	TimeKeeper = _TimeKeeper,
	AdjustmentPool = _AdjustmentPool,
	Batcher = _Batcher,
	Bezier = _Bezier,
	DataCatalog = _DataCatalog,
	RandomRotator = _RandomRotator,
	Respawner = _Respawner,
	Lottery = _Lottery,
	Future = _Future,
	RateLimiter = _RateLimiter,
	DynamicOctree = _DynamicOctree,
	ObjectPool = _ObjectPool,
	Queue = _Queue,
	LinearValue = _LinearValue,
}