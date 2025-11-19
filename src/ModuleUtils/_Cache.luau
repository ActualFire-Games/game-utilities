--!strict
--@author: crusherfire
--@date: 3/7/25
--[[@description:
    Basic cache class with a pre-defined size.
    Has a _lookup table for O(1) key lookups.
]]
-----------------------------
-- TYPES --
-----------------------------
type CacheEntry = {
	Key: any,
	Value: any,
}
type fields = {
	_size: number,
	_cache: { CacheEntry },
	_lookup: { [any]: number },  -- maps key -> index in _cache
}

-----------------------------
-- VARIABLES --
-----------------------------
local CacheClass = {}
local MT = {}
MT.__index = MT
MT.__newindex = function()
	error("Unable to set a new value directly in CacheType object!")
end
export type CacheType = typeof(setmetatable({} :: fields, MT))

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- Updates the lookup mapping for all cache entries starting at startIndex.
local function updateLookupFrom(self: CacheType, startIndex: number)
	for i = startIndex, #self._cache do
		local entry = self._cache[i]
		self._lookup[entry.Key] = i
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates a new cache. Default size is 100 elements.
function CacheClass.new(size: number?): CacheType
	local size = size or 100
	
	local self: fields = {
		_size = size,
		_cache = table.create(size),
		_lookup = {},
	}

	return setmetatable(self, MT)
end

function MT.Get(self: CacheType, key: any): (any, number?)
	assert(key ~= nil, "Key must be non-nil.")
	local index = self._lookup[key]
	if index then
		return self._cache[index].Value, index
	end
	return nil, nil
end

-- Provide nil value to remove from cache.
function MT.Set(self: CacheType, key: any, value: any)
	assert(key ~= nil, "Key must be non-nil.")
	local isNilValue = (value == nil)
	local _, index = self:Get(key)

	if index then
		-- Remove the entry from its current position.
		local data = table.remove(self._cache, index)
		self._lookup[key] = nil
		updateLookupFrom(self, index :: number)
		if not isNilValue and data then
			data.Value = value
			table.insert(self._cache, data)
			self._lookup[key] = #self._cache
		end
	elseif not isNilValue then
		local data = {
			Key = key,
			Value = value,
		}
		if #self._cache >= self._size then
			-- Remove first element if at capacity.
			local removed = table.remove(self._cache, 1) :: CacheEntry
			self._lookup[removed.Key] = nil
			updateLookupFrom(self, 1)
		end
		table.insert(self._cache, data)
		self._lookup[key] = #self._cache
	end
end

-----------------------------
-- MAIN --
-----------------------------
return CacheClass