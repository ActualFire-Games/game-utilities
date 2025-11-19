--!strict
--@title: FunctionUtils
--@author: crusherfire
--@date: 3/30/24
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local _vector = require(script._vector)
local _interface = require(script._interface)
local _table = require(script._table)
local _format = require(script._format)
local _game = require(script._game)
local _character = require(script._character)
local _object = require(script._object)
local _random = require(script._random)
local _math = require(script._math)
local _observers = require(script._observers)
local _debugDraw = require(script._debugDraw)
local _player = require(script._player)
local _t = require(script._t)
local _buffer = require(script._buffer)
local _camera = require(script._camera)
local _vfx = require(script._vfx)
local _cframe = require(script._cframe)
local _base64 = require(script._base64)
local _remotes = require(script._remotes)
local _region3 = require(script._region3)
local _Sera = require(script._Sera)
local _proxy = require(script._proxy)
local _input = require(script._input)
local _color = require(script._color)
local _dateTime = require(script._dateTime)
local _agent = require(script._agent)
local _thread = require(script._thread)
local _localization = require(script._localization)
local _debug = require(script._debug)
local _Spring = require(script._Spring)

-----------------------------
-- TYPES --
-----------------------------

export type Schema = _Sera.Schema

-----------------------------
-- VARIABLES --
-----------------------------
local Util = {
	Vector = _vector,
	Interface = _interface,
	Table = _table,
	Format = _format,
	Game = _game,
	Character = _character,
	Player = _player,
	Object = _object,
	Random = _random,
	Math = _math,
	Observers = _observers,
	DebugDraw = _debugDraw,
	t = _t,
	Buffer = _buffer,
	Camera = _camera,
	VFX = _vfx,
	CFrame = _cframe,
	Base64 = _base64,
	Remotes = _remotes,
	Region3 = _region3,
	Sera = _Sera,
	Proxy = _proxy,
	Input = _input,
	Color = _color,
	DateTime = _dateTime,
	Agent = _agent,
	Thread = _thread,
	Localization = _localization,
	Debug = _debug,
	Spring = _Spring
}

-----------------------------
-- MAIN --
-----------------------------
return Util