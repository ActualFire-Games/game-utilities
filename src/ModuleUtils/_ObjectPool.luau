--!strict
--@author: crusherfire
--@date: 9/27/25
--[[@description:
	Allows you to initally clone many instances to be re-used to avoid the costs of cloning and creating new instances.
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Trove = require("./_Trove")
local FunctionUtils = require("../FunctionUtils")
local t = FunctionUtils.t

-----------------------------
-- TYPES --
-----------------------------
-- For all of the properties/fields of an object made from this class.
type fields = {
	_trove: Trove.TroveType,
	_userData: { [any]: any },
	
	_params: PoolParams,
	_folder: Folder,
	_objects: { any },
	_grabbed: { [any]: boolean },
}

export type PoolParams = {
	Template: any,
	Size: number?, -- default size is 1000
	StorageLocation: any?, -- default is ReplicatedStorage
	OnCreate: ( (obj: any) -> () )?,
	OnGrab: ( (obj: any) -> () )?,
	OnRelease: ( (obj: any) -> () )?,
}

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT
export type ObjectPool = typeof(setmetatable({} :: fields, MT))

local objectCache = {}

-- CONSTANTS --
Module.STORAGE_CF_EXTREME = CFrame.new(0, 10e8, 0) -- 1 billion studs (can have precision issues)
Module.STORAGE_CF_FAR = CFrame.new(0, 10e4, 0) -- 100K studs
Module.STORAGE_CF_STANDARD = CFrame.new(0, 10e3, 0) -- 10K studs (safe precision)
local DEFAULT_SIZE = 1000

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- CLASS FUNCTIONS --
-----------------------------

--[[
	Creates a new object pool.
	Default size is 1000 objects.
]]
function Module.new(params: PoolParams): ObjectPool
	local self = setmetatable({} :: fields, MT) :: ObjectPool
	self._trove = Trove.new()
	self._userData = {}
	
	self._params = table.clone(params)
	self._folder = self._trove:Add(FunctionUtils.Game.create("Folder", {
		Name = `{params.Template.Name}_Objects`,
		Parent = params.StorageLocation or ReplicatedStorage
	}))
	self._objects = table.create(self._params.Size or DEFAULT_SIZE)
	self._grabbed = table.create(self._params.Size or DEFAULT_SIZE)
	
	self:_Init()
	
	table.insert(objectCache, self)
	return self
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object) == MT
end

function Module:GetObjects(): { ObjectPool }
	return objectCache
end 

-----------------------------
-- METHODS --
-----------------------------

function MT._Init(self: ObjectPool)
	debug.profilebegin("ObjectPool::_Init")
	
	local size = self._params.Size or DEFAULT_SIZE
	for i = 1, size do
		self:_CloneNew()
	end
	
	debug.profileend()
end

function MT._CloneNew(self: ObjectPool): (any, number)
	debug.profilebegin("ObjectPool::_CloneNew")
	local clone = self._trove:Clone(self._params.Template)
	self._trove:Once(clone.Destroying, function()
		warn(`Object '{clone:GetFullName()}' in pool was destroyed by an external system! This should not happen!`)
		local index = table.find(self._objects, clone)
		if index then
			table.remove(self._objects, clone)
		end
		self._grabbed[clone] = nil
		self._trove:Remove(clone)
	end)
	local newIndex = #self._objects + 1
	self._objects[newIndex] = clone
	if self._params.OnCreate then
		task.spawn(self._params.OnCreate, clone)
	end
	clone.Parent = self._folder
	debug.profileend()
	return clone, newIndex
end

-----------------------------
-- SETTERS --
-----------------------------

-----------------------------
-- GETTERS --
-----------------------------

--[[
	Retrieves an object from the pool. If there are no objects available, one will be cloned from the template.
]]
function MT.Grab(self: ObjectPool): any
	local obj = self._objects[1] or self:_CloneNew()
	
	table.remove(self._objects, 1)
	self._grabbed[obj] = true
	if self._params.OnGrab then
		task.spawn(self._params.OnGrab, obj)
	end
	return obj
end

--[[
	Releases the object back into the pool and reparents it back into the storage folder.
]]
function MT.Release(self: ObjectPool, obj: any)
	assert(t.Instance(obj))
	if not self._grabbed[obj] then
		error(`was given obj '{obj:GetFullName()}' that was never grabbed or was destroyed`)
	end
	self._grabbed[obj] = nil
	table.insert(self._objects, obj)
	obj.Parent = self._folder
	if self._params.OnRelease then
		task.spawn(self._params.OnRelease, obj)
	end
end

--[[
	Expands the pool with <code>count</code> additional instances.
]]
function MT.Expand(self: ObjectPool, count: number)
	debug.profilebegin("ObjectPool::Expand")
	for i = 1, count do
		self:_CloneNew()
	end
	debug.profileend()
end

function MT.GetStorageFolder(self: ObjectPool): Folder
	return self._folder
end

function MT.GetTrove(self: ObjectPool): Trove.TroveType
	return self._trove
end

function MT.GetUserData(self: ObjectPool): { [any]: any }
	return self._userData
end

-----------------------------
-- CLEANUP --
-----------------------------

function MT.Destroy(self: ObjectPool)
	self._trove:Clean()
	local i = table.find(objectCache, self)
	if i then
		table.remove(objectCache, i)
	end
end

-----------------------------
-- MAIN --
-----------------------------
return Module