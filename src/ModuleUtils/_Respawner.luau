--!strict
--@author: C0DERACTU4L
--@date: 9/2/2024
--[[@description:
	Respawner class for models 
]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Trove = require("./_Trove")

-----------------------------
-- TYPES --
-----------------------------
-- This is for all of the properties of an object made from this class for type annotation purposes.
type self = {
	_trove: Trove.TroveType,
	
	_instance: PVInstance,
	_humanoid: Humanoid?,
	_instanceCache: PVInstance,
	_instanceParentCache: Instance,
	_respawnTime: number,
}

-----------------------------
-- VARIABLES --
-----------------------------
local Respawner = {}
local MT = {}
MT.__index = MT

export type Respawner = typeof(setmetatable({} :: self, MT))

local respawnCache = {}

-- CONSTANTS --
local DEFAULT_RESPAWN_TIME = 10
local INSTANCE_CACHE_LOCATION = ReplicatedStorage

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Respawner.new(instance: Instance, respawnTime: number?): Respawner
	assert(instance and instance:IsA("PVInstance"), "Expected instance to be of type PV Instance")
	local self = setmetatable({} :: self, MT)

	self._trove = Trove.new()

	self._instance = instance
	self._instanceCache = self._instance:Clone()
	self._instanceCache:RemoveTag("Respawnable")
	self._instanceCache.Parent = INSTANCE_CACHE_LOCATION
	self._instanceParentCache = if self._instance.Parent and self._instance.Parent:IsA("Instance") then self._instance.Parent else workspace
	self._respawnTime = if respawnTime then respawnTime else DEFAULT_RESPAWN_TIME
	
	self._humanoid = self._instance:FindFirstChildWhichIsA("Humanoid")

	if self._humanoid then
		self._trove:Add(self._humanoid.Died:Once(function()
			task.wait(self._respawnTime)
			self._instance:Destroy()
		end))
	end
	
	self._trove:Connect(self._instance.Destroying, function()
		if not self._humanoid then
			task.wait(self._respawnTime)
		end
		self:Respawn()
	end)
	
	table.insert(respawnCache, self)
	return self
end

function Respawner:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object) == MT
end

function Respawner:GetObjectFromInstance(instance): Respawner?
	for _, cachedObject in ipairs(respawnCache) do
		if cachedObject._instance == instance then
			return cachedObject
		end
	end
	return nil
end

function MT.Respawn(self: Respawner)
	self._trove:Clean()
	self._instance = self._instanceCache:Clone()
	self._instance.Parent = self._instanceParentCache
	self._humanoid = self._instance:FindFirstChildWhichIsA("Humanoid")
	
	self._trove:Connect(self._instance.Destroying, function()
		if not self._humanoid then
			task.wait(self._respawnTime)
		end
		self:Respawn()
	end)
	
	if self._humanoid then
		self._trove:Add(self._humanoid.Died:Once(function()
			task.wait(self._respawnTime)
			self._instance:Destroy()
		end))
	end
end

function MT.Destroy(self: Respawner)
	self._trove:Clean()
    local index = table.find(respawnCache, self)
    if index then
        table.remove(respawnCache, index)
    end
end

-----------------------------
-- MAIN --
-----------------------------
return Respawner