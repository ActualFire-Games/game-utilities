--!strict
--@author: crusherfire
--@date: 4/22/25
--[[@description:
	For creating catalog data containers.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Cache = require("./_Cache")
local FunctionUtils = require("../FunctionUtils")
local t = FunctionUtils.t

-----------------------------
-- TYPES --
-----------------------------

export type DataCatalog<T> = {
	_data: { [string]: T },
	_entryCache: Cache.CacheType,
	_entryCount: number,

	-- SUPER hacky for functions w/comments but it works!
	GetRandomEntryUnique: typeof(
		--[[
			Returns a random entry in the data catalog excluding <code>usedKeys</code>.
			If <code>usedKeys</code> excludes all data, a random entry will be selected via <code>:GetRandomEntry()</code>.
		]] 
		function(self: DataCatalog<T>, rng: Random?, usedKeys: { [string]: boolean }?): (string, T)
			return nil :: any, nil :: any
		end
	),
	GetRandomEntry: typeof(
		-- Returns a random entry in the data catalog.
		function(self: DataCatalog<T>, rng: Random?): (string, T)
			return nil :: any, nil :: any
		end
	),
	GetEntries: ( typeof(
		-- Returns all entries. This table is frozen and cannot be modified.
		function(self: DataCatalog<T>): { [string]: T }
			return nil :: any
		end
		)
	),
	GetEnumNames: typeof(
		-- Returns all enum names as an array in the catalog.
		function(self: DataCatalog<T>): { string }
			return {}
		end
	),
	GetEntryByName: ( typeof(
		-- Grabs a guaranteed entry in the catalog based on the <code>enumName</code>.
		-- Throws an error if the <code>enumName</code> is invalid. If this behavior is not desired, index for the entry directly from <code>:GetEntires()</code>
		@deprecated
		function(self: DataCatalog<T>, enumName: string): T
			return nil :: any
		end)
	),
	GetEntryByEnumName: (
		typeof(
			--[[
				Returns the entry based on the given <code>enumName</code>, if any.
			]]
			function(self: DataCatalog<T>, enumName: string): T?
				return nil :: any
			end
		)
	),
	GetEntryByEnumNameStrict: (
		typeof(
			--[[
				Returns the entry based on the given <code>enumName</code>.
				Throws an error if the <code>enumName</code> does not exist in the catalog.
			]]
			function(self: DataCatalog<T>, enumName: string): T
				return nil :: any
			end
		)
	),
	GetEntryByKeyValue: typeof(
		-- Looks for the entry in the catalog based on <code>key</code> and if the value at <code>key</code> matches <code>matchValue</code>.
		function(self: DataCatalog<T>, key: string, matchValue: any): T?
			return nil :: any
		end
	),
	GetEntryByKeyValueStrict: typeof(
		-- Looks for the entry in the catalog based on <code>key</code> and if the value at <code>key</code> matches <code>matchValue</code>.
		function(self: DataCatalog<T>, key: string, matchValue: any): T
			return nil :: any
		end
	),
	GetEntriesByKeyValue: typeof(
		-- Looks for all entries in the catalog based on <code>key</code> and if the value at <code>key</code> matches <code>matchValue</code>.
		function(self: DataCatalog<T>, key: string, matchValue: any): { T }
			return nil :: any
		end
	),
	GetNameByEntry: typeof( 
		-- Looks for the entry in the catalog and returns its name if found.
		-- Results are cached.
		@deprecated
		function(self: DataCatalog<T>, entry: any): string?
			return
		end
	),
	GetEnumNameByEntry: typeof( 
		--[[
			Looks for the entry in the catalog and returns its EnumName, if any.
			Results are cached.
		]]
		function(self: DataCatalog<T>, entry: any): string?
			return
		end
	),
	GetSorted: typeof(
		-- Returns an array of all values and keys in the catalog sorted by <code>comparator</code>
		-- These results are cached with the same comparator!
		function(self: DataCatalog<T>, comparator: (a: T, b: T) -> (boolean)): ( { T }, { string } )
			return nil :: any, nil :: any
		end
	),
	GetEntriesArray: typeof(
		-- Returns an array of all entries in the catalog.
		function(self: DataCatalog<T>): { T }
			return nil :: any
		end
	),
	GetEntryCount: typeof(
		--[[
			Returns the number of entries present in the DataCatalog.
			Result is cached.
		]]
		function(self: DataCatalog<T>): number
			return 0
		end
	)
}

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT

local sortedCatalogCache = FunctionUtils.Table.weakCache("k")

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- CLASS FUNCTIONS --
-----------------------------

-- Freezes the data table and stores it.
function Module.new<T>(data: { [string]: T }): DataCatalog<T>
	local self = setmetatable({}, MT) :: any
	
	self._data = if table.isfrozen(data) then data else table.freeze(data)
	self._entryCache = Cache.new()
	self._entryCount = 0
	for _, _ in data do
		self._entryCount += 1
	end
	
	return self
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	local mt = getmetatable(object)
	return mt ~= nil and mt.__index == MT
end

-----------------------------
-- METHODS --
-----------------------------

-----------------------------
-- SETTERS --
-----------------------------

-----------------------------
-- GETTERS --
-----------------------------

function MT.GetRandomEntryUnique(
	self: DataCatalog<any>,
	rng: Random?,
	usedKeys: { [string]: boolean }?
): (string, any)
	local values, keys = FunctionUtils.Table.toArrayCached(self._data)
	local rng = rng or Random.new(tick())
	local usedKeys = usedKeys or {}

	-- Build a list of available (unused) keys and their indexes
	local availableIndexes = {}

	for index, key in ipairs(keys) do
		if usedKeys[key] then
			continue
		end
		table.insert(availableIndexes, index)
	end

	if #availableIndexes == 0 then
		-- default to any random entry
		return self:GetRandomEntry(rng)
	end

	local randomIndex = availableIndexes[rng:NextInteger(1, #availableIndexes)]
	local key = keys[randomIndex]
	local value = values[randomIndex]

	usedKeys[key] = true
	return key, value
end

function MT.GetRandomEntry(self: DataCatalog<any>, rng: Random?): (string, any)
	local values, keys = FunctionUtils.Table.toArrayCached(self._data)
	local rng = rng or Random.new(tick())
	local int = rng:NextInteger(1, #keys)
	return keys[int], values[int]
end

-- Returns all entries. This table is frozen and cannot be modified.
function MT.GetEntries(self: DataCatalog<any>): any
	return self._data
end

function MT.GetEntriesArray(self: DataCatalog<any>): { any }
	local values = FunctionUtils.Table.toArrayCached(self._data)
	return values
end

function MT.GetEnumNames(self: DataCatalog<any>): { string }
	return select(2, FunctionUtils.Table.toArrayCached(self._data))
end

-- Grabs a guaranteed entry in the catalog based on the <code>enumName</code>.
-- Throws an error if the <code>enumName</code> is invalid. If this behavior is not desired, index for the entry directly from <code>:GetEntires()</code>
@deprecated
function MT.GetEntryByName(self: DataCatalog<any>, enumName: string): any
	local result = self._data[enumName]
	if not result then
		error(`invalid enumName: {enumName}`, 2)
	end
	return result
end

function MT.GetEntryByEnumName(self: DataCatalog<any>, enumName: string): any
	return self._data[enumName]
end

function MT.GetEntryByEnumNameStrict(self: DataCatalog<any>, enumName: string): any
	local result = self._data[enumName]
	if not result then
		error(`invalid enumName '{enumName}'`, 2)
	end
	return result
end

-- Looks for the entry in the catalog based on <code>key</code> and if the value at <code>key</code> matches <code>matchValue</code>.
function MT.GetEntryByKeyValue(self: DataCatalog<any>, key: string, matchValue: any): any?
	for name, entry: any in pairs(self._data) do
		if entry[key] == matchValue then
			return entry
		end
	end
	return
end

--[[
	Looks for the entry in the catalog based on <code>key</code> and if the value at <code>key</code> matches <code>matchValue</code>.
	Errors if no entry is found.
]]
function MT.GetEntryByKeyValueStrict(self: DataCatalog<any>, key: string, matchValue: any): any?
	for name, entry: any in pairs(self._data) do
		if entry[key] == matchValue then
			return entry
		end
	end
	error(`Did not find Key-Value match for key '{key}' value '{matchValue}'`, 2)
end

-- Looks for all entries in the catalog based on <code>key</code> and if the value at <code>key</code> matches <code>matchValue</code>.
function MT.GetEntriesByKeyValue(self: DataCatalog<any>, key: string, matchValue: any): any?
	local result = {}
	for name, entry in pairs(self._data) do
		if entry[key] == matchValue then
			table.insert(result, entry)
		end
	end
	return result
end

-- Looks for the entry in the catalog and returns its name if found.
-- Results are cached.
@deprecated
function MT.GetNameByEntry(self: DataCatalog<any>, entry: any): string?
	local result = self._entryCache:Get(entry)
	if result then
		return if result == true then nil else result
	end
	for name, _entry in pairs(self._data) do
		if _entry == entry then
			result = name
			break
		end
	end
	self._entryCache:Set(entry, result or true)
	return result
end

function MT.GetEnumNameByEntry(self: DataCatalog<any>, entry: any): string?
	local result = self._entryCache:Get(entry)
	if result then
		return if result == true then nil else result
	end
	for name, _entry in pairs(self._data) do
		if _entry == entry then
			result = name
			break
		end
	end
	self._entryCache:Set(entry, result or true)
	return result
end

function MT.GetSorted(self: DataCatalog<any>, comparator: (any, any) -> (boolean)): ( { any }, { string } )
	assert(typeof(comparator) == "function", "Expected comparator to be a function")

	local data = self._data
	local cacheForData = sortedCatalogCache[data]
	if not cacheForData then
		cacheForData = FunctionUtils.Table.weakCache("k")
		sortedCatalogCache[data] = cacheForData
	end

	local cached = cacheForData[comparator]
	if cached then
		-- Return cloned arrays to avoid external mutation
		return table.clone(cached.Values), table.clone(cached.Keys)
	end

	local values, keys = FunctionUtils.Table.toArrayCached(data)

	local indexed = table.create(#values)
	for i = 1, #values do
		indexed[i] = {
			Key = keys[i],
			Value = values[i],
		}
	end

	table.sort(indexed, function(a, b)
		return comparator(a.Value, b.Value)
	end)

	local sortedValues = table.create(#indexed)
	local sortedKeys = table.create(#indexed)
	for i = 1, #indexed do
		sortedValues[i] = indexed[i].Value
		sortedKeys[i] = indexed[i].Key
	end

	cacheForData[comparator] = {
		Values = sortedValues,
		Keys = sortedKeys,
	}

	return table.clone(sortedValues), table.clone(sortedKeys)
end

function MT.GetEntryCount(self: DataCatalog<any>): number
	return self._entryCount
end

-----------------------------
-- CLEANUP --
-----------------------------

-----------------------------
-- MAIN --
-----------------------------
return Module