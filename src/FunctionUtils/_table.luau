--!strict

-- TableUtil
-- Stephen Leitnick
-- September 13, 2017

-- Plus other extra table functions

--[=[
	@class TableUtil

	A collection of helpful table utility functions. Many of these functions are carried over from JavaScript or
	Python that are not present in Lua.

	Tables that only work specifically with arrays or dictionaries are marked as such in the documentation.

	:::info Immutability
	All functions (_except_ `SwapRemove`, `SwapRemoveFirstValue`, and `Lock`) treat tables as immutable and will return
	copies of the given table(s) with the operations performed on the copies.
]=]
local Module = {}

local HttpService = game:GetService("HttpService")
local rng = Random.new()

--[[
	Given an array of values, remove any values found in <code>excludeArray</code>.
	This works on arrays but not dictionaries.
]]
function Module.excludeValues<T>(sourceArray: { T }, excludeArray: { T }): { T }
	assert(typeof(sourceArray) == "table", "expected table for sourceArray")
	assert(typeof(excludeArray) == "table", "expected table for excludeArray")
	
	local excludeLookup: { [T]: boolean } = {}
	for _, value in ipairs(excludeArray) do
		excludeLookup[value] = true
	end

	local result = table.create(#sourceArray)
	for _, value in ipairs(sourceArray) do
		if not excludeLookup[value] then
			table.insert(result, value)
		end
	end

	return result
end

--[[
	Given an array of values (must be comparable with ==), remove any duplicate values.
]]
function Module.removeDuplicates<T>(array: { T }): { T }
	local result = table.create(#array)
	local seen: { [T]: boolean } = {}
	
	for _, value in ipairs(array) do
		if not seen[value] then
			table.insert(result, value)
			seen[value] = true
		end
	end
	
	return result
end

do
	local metatables = {
		k = { __mode = "k" },
		v = { __mode = "v" },
		kv = { __mode = "kv" }
	}
	-- Creates and returns a new weak table for caching purposes.
	function Module.weakCache(mode: "k" | "v" | "kv"): { [any]: any }
		return setmetatable({}, metatables[mode]) :: any
	end
end

--[=[
	@within TableUtil
	@function Copy
	@param tbl table -- Table to copy
	@param deep boolean? -- Whether or not to perform a deep copy
	@return table

	Creates a copy of the given table. By default, a shallow copy is
	performed. For deep copies, a second boolean argument must be
	passed to the function.

	:::caution No cyclical references
	Deep copies are _not_ protected against cyclical references. Passing
	a table with cyclical references _and_ the `deep` parameter set to
	`true` will result in a stack-overflow.
]=]
local function Copy<T>(t: T, deep: boolean?): T
	if not deep then
		return (table.clone(t :: any) :: any) :: T
	end
	local function deepCopy(object: any)
		assert(typeof(object) == "table", "Expected table for deepCopy!")
		-- Returns a deep copy of the provided table.
		local newObject = setmetatable({}, getmetatable(object)) -- Clone metaData

		for index: any, value: any in object do
			if typeof(value) == "table" then
				newObject[index] = deepCopy(value)
				continue
			end

			newObject[index] = value
		end

		return newObject
	end
	return deepCopy(t :: any) :: T
end



--[=[
	@within TableUtil
	@function Sync
	@param srcTbl table -- Source table
	@param templateTbl table -- Template table
	@return table

	Synchronizes the `srcTbl` based on the `templateTbl`. This will make
	sure that `srcTbl` has all of the same keys as `templateTbl`, including
	removing keys in `srcTbl` that are not present in `templateTbl`. This
	is a _deep_ operation, so any nested tables will be synchronized as
	well.

	```lua
	local template = {kills = 0, deaths = 0, xp = 0}
	local data = {kills = 10, experience = 12}
	data = TableUtil.Sync(data, template)
	print(data) --> {kills = 10, deaths = 0, xp = 0}
	```

	:::caution Data Loss Warning
	This is a two-way sync, so the source table will have data
	_removed_ that isn't found in the template table. This can
	be problematic if used for player data, where there might
	be dynamic data added that isn't in the template.

	For player data, use `TableUtil.Reconcile` instead.
]=]
local function Sync<S, T>(srcTbl: S, templateTbl: T): T
	assert(type(srcTbl) == "table", "First argument must be a table")
	assert(type(templateTbl) == "table", "Second argument must be a table")

	local tbl = table.clone(srcTbl)

	-- If 'tbl' has something 'templateTbl' doesn't, then remove it from 'tbl'
	-- If 'tbl' has something of a different type than 'templateTbl', copy from 'templateTbl'
	-- If 'templateTbl' has something 'tbl' doesn't, then add it to 'tbl'
	for k, v in pairs(tbl) do
		local vTemplate = templateTbl[k]

		-- Remove keys not within template:
		if vTemplate == nil then
			tbl[k] = nil

			-- Synchronize data types:
		elseif type(v) ~= type(vTemplate) then
			if type(vTemplate) == "table" then
				tbl[k] = Copy(vTemplate, true)
			else
				tbl[k] = vTemplate
			end

			-- Synchronize sub-tables:
		elseif type(v) == "table" then
			tbl[k] = Sync(v, vTemplate)
		end
	end

	-- Add any missing keys:
	for k, vTemplate in pairs(templateTbl) do
		local v = tbl[k]

		if v == nil then
			if type(vTemplate) == "table" then
				tbl[k] = Copy(vTemplate, true)
			else
				tbl[k] = vTemplate
			end
		end
	end

	return (tbl :: any) :: T
end

--[=[
	@within TableUtil
	@function Reconcile
	@param source table
	@param template table
	@return table

	Performs a one-way sync on the `source` table against the
	`template` table. Any keys found in `template` that are
	not found in `source` will be added to `source`. This is
	useful for syncing player data against data template tables
	to ensure players have all the necessary keys, while
	maintaining existing keys that may no longer be in the
	template.

	This is a deep operation, so nested tables will also be
	properly reconciled.

	```lua
	local template = {kills = 0, deaths = 0, xp = 0}
	local data = {kills = 10, abc = 20}
	local correctedData = TableUtil.Reconcile(data, template)
	
	print(correctedData) --> {kills = 10, deaths = 0, xp = 0, abc = 20}
	```
]=]
local function Reconcile<S, T>(src: S, template: T): S & T
	assert(type(src) == "table", "First argument must be a table")
	assert(type(template) == "table", "Second argument must be a table")

	local tbl = table.clone(src)

	for k, v in template do
		local sv = src[k]
		if sv == nil then
			if type(v) == "table" then
				tbl[k] = Copy(v, true)
			else
				tbl[k] = v
			end
		elseif type(sv) == "table" then
			if type(v) == "table" then
				tbl[k] = Reconcile(sv, v)
			else
				tbl[k] = Copy(sv, true)
			end
		end
	end

	return (tbl :: any) :: S & T
end

--[=[
	@within TableUtil
	@function SwapRemove
	@param tbl table -- Array
	@param i number -- Index

	Removes index `i` in the table by swapping the value at `i` with
	the last value in the array, and then trimming off the last
	value from the array.

	This allows removal of the value at `i` in `O(1)` time, but does
	not preserve array ordering. If a value needs to be removed from
	an array, but ordering of the array does not matter, using
	`SwapRemove` is always preferred over `table.remove`.

	In the following example, we remove "B" at index 2. SwapRemove does
	this by moving the last value "E" over top of "B", and then trimming
	off "E" at the end of the array:
	```lua
	local t = {"A", "B", "C", "D", "E"}
	TableUtil.SwapRemove(t, 2) -- Remove "B"
	print(t) --> {"A", "E", "C", "D"}
	```

	:::note Arrays only
	This function works on arrays, but not dictionaries.
]=]
local function SwapRemove<T>(t: { T }, i: number)
	local n = #t
	t[i] = t[n]
	t[n] = nil
end

--[=[
	@within TableUtil
	@function SwapRemoveFirstValue
	@param tbl table -- Array
	@param v any -- Value to find
	@return number?

	Performs `table.find(tbl, v)` to find the index of the given
	value, and then performs `TableUtil.SwapRemove` on that index.

	```lua
	local t = {"A", "B", "C", "D", "E"}
	TableUtil.SwapRemoveFirstValue(t, "C")
	print(t) --> {"A", "B", "E", "D"}
	```

	:::note Arrays only
	This function works on arrays, but not dictionaries.
]=]
local function SwapRemoveFirstValue<T>(t: { T }, v: T): number?
	local index: number? = table.find(t, v)
	if index then
		SwapRemove(t, index)
	end
	return index
end

--[=[
	@within TableUtil
	@function Map
	@param tbl table
	@param predicate (value: any, key: any, tbl: table) -> newValue: any
	@return table

	Performs a map operation against the given table, which can be used to
	map new values based on the old values at given keys/indices.

	For example:

	```lua
	local t = {A = 10, B = 20, C = 30}
	local t2 = TableUtil.Map(t, function(value)
		return value * 2
	end)
	print(t2) --> {A = 20, B = 40, C = 60}
	```
]=]
local function Map<T, M>(t: { T }, f: (T, number, { T }) -> M): { M }
	assert(type(t) == "table", "First argument must be a table")
	assert(type(f) == "function", "Second argument must be a function")
	local newT = table.create(#t)
	for k, v in t do
		newT[k] = f(v, k, t)
	end
	return newT
end

--[=[
	@within TableUtil
	@function Filter
	@param tbl table
	@param predicate (value: any, key: any, tbl: table) -> keep: boolean
	@return table

	Performs a filter operation against the given table, which can be used to
	filter out unwanted values from the table.

	For example:

	```lua
	local t = {A = 10, B = 20, C = 30}
	local t2 = TableUtil.Filter(t, function(value, key)
		return value > 15
	end)
	print(t2) --> {B = 20, C = 30}
	```
]=]
local function Filter<T>(t: { T }, shouldKeep: (T, any, { T }) -> boolean): { T }
	assert(type(t) == "table", "First argument must be a table")
	assert(type(shouldKeep) == "function", "Second argument must be a function")
	local newT = table.create(#t)
	if #t > 0 then
		local n = 0
		for i, v in t do
			if shouldKeep(v, i, t) then
				n += 1
				newT[n] = v
			end
		end
	else
		for k, v in t do
			if shouldKeep(v, k, t) then
				newT[k] = v
			end
		end
	end
	return newT
end

--[=[
	@within TableUtil
	@function Reduce
	@param tbl table
	@param predicate (accumulator: any, value: any, index: any, tbl: table) -> result: any
	@return table

	Performs a reduce operation against the given table, which can be used to
	reduce the table into a single value. This could be used to sum up a table
	or transform all the values into a compound value of any kind.

	For example:

	```lua
	local t = {10, 20, 30, 40}
	local result = TableUtil.Reduce(t, function(accum, value)
		return accum + value
	end)
	print(result) --> 100
	```
]=]
local function Reduce<T, R>(t: { T }, predicate: (R, T, any, { T }) -> R, init: R): R
	assert(type(t) == "table", "First argument must be a table")
	assert(type(predicate) == "function", "Second argument must be a function")
	local result = init :: R
	if #t > 0 then
		local start = 1
		if init == nil then
			result = (t[1] :: any) :: R
			start = 2
		end
		for i = start, #t do
			result = predicate(result, t[i], i, t)
		end
	else
		local start = nil
		if init == nil then
			result = (next(t) :: any) :: R
			start = result
		end
		for k, v in next, t, start :: any? do
			result = predicate(result, v, k, t)
		end
	end
	return result
end

--[=[
	@within TableUtil
	@function Assign
	@param target table
	@param ... table
	@return table

	Copies all values of the given tables into the `target` table.

	```lua
	local t = {A = 10}
	local t2 = {B = 20}
	local t3 = {C = 30, D = 40}
	local newT = TableUtil.Assign(t, t2, t3)
	print(newT) --> {A = 10, B = 20, C = 30, D = 40}
	```
]=]
local function Assign<T>(target: { T }, ...: { any }): { T } & { any }
	local tbl = table.clone(target)
	for _, src in { ... } do
		for k, v in src do
			tbl[k] = v
		end
	end
	return tbl
end

--[=[
	@within TableUtil
	@function Extend
	@param target table
	@param extension table
	@return table

	Extends the target array with the extension array.

	```lua
	local t = {10, 20, 30}
	local t2 = {30, 40, 50}
	local tNew = TableUtil.Extend(t, t2)
	print(tNew) --> {10, 20, 30, 30, 40, 50}
	```

	:::note Arrays only
	This function works on arrays, but not dictionaries.
]=]
local function Extend<T, E>(target: { T }, extension: { E }): { T } & { E }
	local tbl = table.clone(target) :: { any }
	for _, v in extension do
		table.insert(tbl, v)
	end
	return tbl
end

--[=[
	@within TableUtil
	@function Reverse
	@param tbl table
	@return table

	Reverses the array.

	```lua
	local t = {1, 5, 10}
	local tReverse = TableUtil.Reverse(t)
	print(tReverse) --> {10, 5, 1}
	```

	:::note Arrays only
	This function works on arrays, but not dictionaries.
]=]
local function Reverse<T>(tbl: { T }): { T }
	local n = #tbl
	local tblRev = table.create(n)
	for i = 1, n do
		tblRev[i] = tbl[n - i + 1]
	end
	return tblRev
end

--[=[
	@within TableUtil
	@function Shuffle
	@param tbl table
	@param rngOverride Random?
	@return table

	Shuffles the table.

	```lua
	local t = {1, 2, 3, 4, 5, 6, 7, 8, 9}
	local shuffled = TableUtil.Shuffle(t)
	print(shuffled) --> e.g. {9, 4, 6, 7, 3, 1, 5, 8, 2}
	```

	:::note Arrays only
	This function works on arrays, but not dictionaries.
]=]
local function Shuffle<T>(tbl: { T }, rngOverride: Random?): { T }
	assert(type(tbl) == "table", "First argument must be a table")
	local shuffled = table.clone(tbl)
	local random = if typeof(rngOverride) == "Random" then rngOverride else rng
	for i = #tbl, 2, -1 do
		local j = random:NextInteger(1, i)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end
	return shuffled
end

--[=[
	@within TableUtil
	@function Sample
	@param tbl table
	@param sampleSize number
	@param rngOverride Random?
	@return table

	Returns a random sample of the table.

	```lua
	local t = {1, 2, 3, 4, 5, 6, 7, 8, 9}
	local sample = TableUtil.Sample(t, 3)
	print(sample) --> e.g. {6, 2, 5}
	```

	:::note Arrays only
	This function works on arrays, but not dictionaries.
]=]
local function Sample<T>(tbl: { T }, size: number, rngOverride: Random?): { T }
	assert(type(tbl) == "table", "First argument must be a table")
	assert(type(size) == "number", "Second argument must be a number")

	-- If given table is empty, just return a new empty table:
	local len = #tbl
	if len == 0 then
		return {}
	end

	local shuffled = table.clone(tbl)
	local sample = table.create(size)
	local random = if typeof(rngOverride) == "Random" then rngOverride else rng

	-- Clamp sample size to be no larger than the given table size:
	size = math.clamp(size, 1, len)

	for i = 1, size do
		local j = random:NextInteger(i, len)
		shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
	end

	table.move(shuffled, 1, size, 1, sample)

	return sample
end

--[=[
	@within TableUtil
	@function Flat
	@param tbl table
	@param depth number?
	@return table

	Returns a new table where all sub-arrays have been
	bubbled up to the top. The depth at which the scan
	is performed is dictated by the `depth` parameter,
	which is set to `1` by default.

	```lua
	local t = {{10, 20}, {90, 100}, {30, 15}}
	local flat = TableUtil.Flat(t)
	print(flat) --> {10, 20, 90, 100, 30, 15}
	```

	:::note Arrays only
	This function works on arrays, but not dictionaries.
]=]
local function Flat<T>(tbl: { T }, depth: number?): { T }
	local maxDepth: number = if type(depth) == "number" then depth else 1
	local flatTbl = table.create(#tbl)
	local function Scan(t: { any }, d: number)
		for _, v in t do
			if type(v) == "table" and d < maxDepth then
				Scan(v, d + 1)
			else
				table.insert(flatTbl, v)
			end
		end
	end
	Scan(tbl, 0)
	return flatTbl
end

--[=[
	@within TableUtil
	@function FlatMap
	@param tbl table
	@param predicate (key: any, value: any, tbl: table) -> newValue: any
	@return table

	Calls `TableUtil.Map` on the given table and predicate, and then
	calls `TableUtil.Flat` on the result from the map operation.

	```lua
	local t = {10, 20, 30}
	local result = TableUtil.FlatMap(t, function(value)
		return {value, value * 2}
	end)
	print(result) --> {10, 20, 20, 40, 30, 60}
	```

	:::note Arrays only
	This function works on arrays, but not dictionaries.
]=]
local function FlatMap<T, M>(tbl: { T }, callback: (T, number, { T }) -> M): { M }
	return Flat(Map(tbl, callback))
end

--[=[
	@within TableUtil
	@function Keys
	@param tbl table
	@return table

	Returns an array with all the keys in the table.

	```lua
	local t = {A = 10, B = 20, C = 30}
	local keys = TableUtil.Keys(t)
	print(keys) --> {"A", "B", "C"}
	```

	:::caution Ordering
	The ordering of the keys is never guaranteed. If order is imperative, call
	`table.sort` on the resulting `keys` array.
	```lua
	local keys = TableUtil.Keys(t)
	table.sort(keys)
	```
]=]
local function Keys<K, V>(tbl: { [K]: V }): { K }
	local keys = table.create(#tbl)
	for k in tbl do
		table.insert(keys, k)
	end
	return keys
end

--[=[
	@within TableUtil
	@function Values
	@param tbl table
	@return table

	Returns an array with all the values in the table.

	```lua
	local t = {A = 10, B = 20, C = 30}
	local values = TableUtil.Values(t)
	print(values) --> {10, 20, 30}
	```

	:::caution Ordering
	The ordering of the values is never guaranteed. If order is imperative, call
	`table.sort` on the resulting `values` array.
	```lua
	local values = TableUtil.Values(t)
	table.sort(values)
	```
]=]
local function Values<K, V>(tbl: { [K]: V }): { V }
	local values = table.create(#tbl)
	for _, v in tbl do
		table.insert(values, v)
	end
	return values
end

--[=[
	@within TableUtil
	@function Find
	@param tbl table
	@param callback (value: any, index: any, tbl: table) -> boolean
	@return (value: any?, key: any?)

	Performs a linear scan across the table and calls `callback` on
	each item in the array. Returns the value and key of the first
	pair in which the callback returns `true`.

	```lua
	local t = {
		{Name = "Bob", Age = 20};
		{Name = "Jill", Age = 30};
		{Name = "Ann", Age = 25};
	}

	-- Find first person who has a name starting with J:
	local firstPersonWithJ = TableUtil.Find(t, function(person)
		return person.Name:sub(1, 1):lower() == "j"
	end)

	print(firstPersonWithJ) --> {Name = "Jill", Age = 30}
	```

	:::caution Dictionary Ordering
	While `Find` can also be used with dictionaries, dictionary ordering is never
	guaranteed, and thus the result could be different if there are more
	than one possible matches given the data and callback function.
]=]
local function Find<K, V>(tbl: { [K]: V }, callback: (V, K, { [K]: V }) -> boolean): (V?, K?)
	for k, v in tbl do
		if callback(v, k, tbl) then
			return v, k
		end
	end
	return nil, nil
end

--[=[
	@within TableUtil
	@function Every
	@param tbl table
	@param callback (value: any, index: any, tbl: table) -> boolean
	@return boolean

	Returns `true` if the `callback` also returns `true` for _every_
	item in the table.

	```lua
	local t = {10, 20, 40, 50, 60}

	local allAboveZero = TableUtil.Every(t, function(value)
		return value > 0
	end)

	print("All above zero:", allAboveZero) --> All above zero: true
	```
]=]
local function Every<K, V>(tbl: { [K]: V }, callback: (V, K, { [K]: V }) -> boolean): boolean
	for k, v in tbl do
		if not callback(v, k, tbl) then
			return false
		end
	end
	return true
end

--[=[
	@within TableUtil
	@function Some
	@param tbl table
	@param callback (value: any, index: any, tbl: table) -> boolean
	@return boolean

	Returns `true` if the `callback` also returns `true` for _at least
	one_ of the items in the table.

	```lua
	local t = {10, 20, 40, 50, 60}

	local someBelowTwenty = TableUtil.Some(t, function(value)
		return value < 20
	end)

	print("Some below twenty:", someBelowTwenty) --> Some below twenty: true
	```
]=]
local function Some<K, V>(tbl: { [K]: V }, callback: (V, K, { [K]: V }) -> boolean): boolean
	for k, v in tbl do
		if callback(v, k, tbl) then
			return true
		end
	end
	return false
end

--[=[
	@within TableUtil
	@function Truncate
	@param tbl table
	@param length number
	@return table

	Returns a new table truncated to the length of `length`. Any length
	equal or greater than the current length will simply return a
	shallow copy of the table.

	```lua
	local t = {10, 20, 30, 40, 50, 60, 70, 80}
	local tTruncated = TableUtil.Truncate(t, 3)
	print(tTruncated) --> {10, 20, 30}
	```
]=]
local function Truncate<T>(tbl: { T }, len: number): { T }
	local n = #tbl
	len = math.clamp(len, 1, n)
	return if len == n then table.clone(tbl) else table.move(tbl, 1, len, 1, table.create(len))
end

--[=[
	@within TableUtil
	@function Zip
	@param ... table
	@return (iter: (t: table, k: any) -> (key: any?, values: table?), tbl: table, startIndex: any?)

	Returns an iterator that can scan through multiple tables at the same time side-by-side, matching
	against shared keys/indices.

	```lua
	local t1 = {10, 20, 30, 40, 50}
	local t2 = {60, 70, 80, 90, 100}

	for key,values in TableUtil.Zip(t1, t2) do
		print(key, values)
	end

	--[[
		Outputs:
		1 {10, 60}
		2 {20, 70}
		3 {30, 80}
		4 {40, 90}
		5 {50, 100}
	--]]
	```
]=]
local function Zip(...: { [any]: any }): ((t: { any }, k: any) -> (any, any), { any }, any)
	assert(select("#", ...) > 0, "Must supply at least 1 table")
	local function ZipIteratorArray(all: { any }, k: number): (number?, { any }?)
		k += 1
		local values = {}
		for i, t in all do
			local v = t[k]
			if v ~= nil then
				values[i] = v
			else
				return nil, nil
			end
		end
		return k, values
	end
	local function ZipIteratorMap(all: { [any]: any }, k: any): (number?, { any }?)
		local values = {}
		for i, t in all do
			local v = next(t, k)
			if v ~= nil then
				values[i] = v
			else
				return nil, nil
			end
		end
		return k, values
	end
	local all = { ... }
	if #all[1] > 0 then
		return ZipIteratorArray, all, 0
	else
		return ZipIteratorMap, all, nil
	end
end

--[=[
	@within TableUtil
	@function Lock
	@param tbl table
	@return table

	Locks the table using `table.freeze`, as well as any
	nested tables within the given table. This will lock
	the whole deep structure of the table, disallowing any
	further modifications.

	```lua
	local tbl = {xyz = {abc = 32}}
	tbl.xyz.abc = 28 -- Works fine
	TableUtil.Lock(tbl)
	tbl.xyz.abc = 64 -- Will throw an error (cannot modify readonly table)
	```
]=]
local function Lock<T>(tbl: T): T
	local function Freeze(t: { [any]: any })
		for k, v in pairs(t) do
			if type(v) == "table" then
				t[k] = Freeze(v)
			end
		end
		return table.freeze(t)
	end
	return Freeze(tbl :: any)
end

--[=[
	@within TableUtil
	@function IsEmpty
	@param tbl table
	@return boolean

	Returns `true` if the given table is empty. This is
	simply performed by checking if `next(tbl)` is `nil`
	and works for both arrays and dictionaries. This is
	useful when needing to check if a table is empty but
	not knowing if it is an array or dictionary.

	```lua
	TableUtil.IsEmpty({}) -- true
	TableUtil.IsEmpty({"abc"}) -- false
	TableUtil.IsEmpty({abc = 32}) -- false
	```
]=]
local function IsEmpty(tbl: { [any]: any }): boolean
	return next(tbl) == nil
end

--[=[
	@within TableUtil
	@function EncodeJSON
	@param value any
	@return string

	Proxy for [`HttpService:JSONEncode`](https://developer.roblox.com/en-us/api-reference/function/HttpService/JSONEncode).
]=]
local function EncodeJSON(value: any): string
	return HttpService:JSONEncode(value)
end

--[=[
	@within TableUtil
	@function DecodeJSON
	@param value any
	@return string

	Proxy for [`HttpService:JSONDecode`](https://developer.roblox.com/en-us/api-reference/function/HttpService/JSONDecode).
]=]
local function DecodeJSON(str: string): any
	return HttpService:JSONDecode(str)
end

-- Checks if the tables store the exact same values. Can be used for __eq metamethod
-- This is not a deep operation.
function Module.checkTableEquality(table1: { [any]: any }, table2: { [any]: any }): boolean
	if rawequal(table1, table2) then
		return true
	end
	
	for i, v in pairs(table1) do
		if table2[i] ~= v then
			return false
		end
	end

	for i, v in pairs(table2) do
		if table1[i] ~= v then
			return false
		end
	end

	return true
end

function Module.getValueFromKeyRecursive(key: any, dictionary: {[any]: any}): any?
	if not rawget(dictionary, key) then
		for _, thing in pairs(dictionary) do
			if typeof(thing) ~= "table" then
				continue
			end

			local value = Module.getValueFromKeyRecursive(key, thing)
			if value then
				return value
			end
		end
	else
		return rawget(dictionary, key)
	end

	return nil
end

function Module.getValueFromStringPatternRecursive(pattern: string, dictionary: {[any]: any}): any?
	local pattern = string.lower(pattern)
	for key, thing in pairs(dictionary) do
		-- string.find() is faster than string.match() as we don't need to make a new substring
		local found = string.find(string.lower(key), pattern)
		if not found and typeof(thing) == "table" then
			local value = Module.getValueFromStringPatternRecursive(pattern, thing)
			if value then
				return value
			end
		elseif found then
			return thing
		end
	end

	return nil
end

-- Returns a new array that is the result of into and from
function Module.mergeArrays(into: {[number]: any}, from: {[number]: any})
	local length = #into
	local newArray = table.clone(into)
	for i, v in ipairs(from) do
		newArray[length + i] = v
	end
	return newArray
end

-- Returns a new merged dictionary of the given dictionaries.
-- If any keys match, the first encountered key will have precendence!
function Module.mergeDict(...: { [any]: any })
	local dictionaries = {...}
	local result = {}

	for index, dict in ipairs(dictionaries) do
		assert(typeof(dict) == "table", "invalid table given")
		for key, value in pairs(dict) do
			-- Only set if this key hasn't been set yet
			if result[key] == nil then
				result[key] = value
			end
		end
	end

	return result
end

--[[
	Returns a new merged dictionary of the given dictionaries.
	Errors if any matching keys are found.
]]
function Module.mergeDictStrict(...: { [any]: any })
	local dictionaries = {...}
	local result = {}

	for index, dict in ipairs(dictionaries) do
		assert(typeof(dict) == "table", "invalid table given")
		for key, value in pairs(dict) do
			-- Only set if this key hasn't been set yet
			if result[key] == nil then
				result[key] = value
			else
				error(`found matching key '{key}'`, 2)
			end
		end
	end

	return result
end

function Module.match(list: {}, partial: string)
	assert(list, "list is invalid or nil")
	assert(partial, "partial is invalid or nil")

	local matches = {}
	for _, str in pairs(list) do
		if string.lower(str):sub(1, #partial) == string.lower(partial) then
			table.insert(matches, str)
		end
	end

	return matches
end

do
	-- Converts the dictionary to two arrays containing the keys and values.
	function Module.toArray<K, V>(dict: { [K]: V }): ({ V }, { K })
		assert(dict, "Dictionary is invalid or nil")
		local vResult = {}
		local kResult = {}
		for k, v in dict do
			table.insert(kResult, k)
			table.insert(vResult, v)
		end
		return vResult, kResult
	end
	
	local cache = Module.weakCache("k")
	-- Converts the dictionary to two arrays containing the keys and values.
	-- Results are cached for the same input and shallow copied versions are returned.
	-- Do not use if the input table is mutated during runtime.
	function Module.toArrayCached<K, V>(dict: { [K]: V }): ({ V }, { K })
		assert(dict, "Dictionary is invalid or nil")

		local cached = cache[dict]
		if cached then
			return table.clone(cached.Values), table.clone(cached.Keys)
		end

		local vResult, kResult = Module.toArray(dict)
		local result = { Values = vResult, Keys = kResult }
		cache[dict] = result
		return table.clone(result.Values), table.clone(result.Keys)
	end
end

do
	-- Converts the array to a dictionary where the values become the keys and the indexes become the values.
	function Module.toDict<I, V>(list: { [I]: V }): { [V]: I }
		assert(list, "list is invalid or nil")

		local newDict = {}
		for i, v in pairs(list) do
			newDict[v] = i
		end

		return newDict
	end
	
	local cache = Module.weakCache("k")
	-- Converts the list to a dictionary where the values become the keys and the indexes become the values.
	-- Results are cached for the same input and a shallow copied version is returned.
	-- Do not use if the input table is mutated during runtime.
	function Module.toDictCached<I, V>(list: { [I]: V }): { [V]: I }
		assert(list, "list is invalid or nil")

		local cached = cache[list]
		if cached then
			return table.clone(cached)
		end

		local newDict = Module.toDict(list)

		cache[list] = newDict
		return table.clone(newDict)
	end
end

function Module.getIndexes(listOrDict: {})
	assert(listOrDict, "listOrDict is invalid or nil")

	local indexes = {}
	for i, _ in pairs(listOrDict) do
		table.insert(indexes, i)
	end

	return indexes
end

function Module.getValues(listOrDict: {})
	assert(listOrDict, "listOrDict is invalid or nil")

	local values = {}
	for _, v in pairs(listOrDict) do
		table.insert(values, v)
	end

	return values
end

function Module.length(listOrDict: {}): number
	local count = 0
	for _, _ in listOrDict do
		count += 1
	end
	return count
end

-- Takes an array and segregates it into chunks based on the passed array size.
function Module.chunkArray<T>(array: { T }, chunkSize: number): { { T } }
	local chunks = {}
	for i = 1, #array, chunkSize do
		table.insert(chunks, { table.unpack(array, i, math.min(i + chunkSize - 1, #array)) })
	end
	return chunks
end

-- Recursively traverse over a table with an optional predicate.
-- <strong>shouldVisit</strong>: Will be given all values (including other tables)
-- This automatically skips already-seen tables to prevent infinite loops.
function Module.simpleTraverse(
	sourceTbl: { [any]: any },
	onVisit: (key: any, value: any, path: { any }, node: { [any]: any }) -> (),
	shouldVisit: ( (key: any, value: any, path: { any }, node: { [any]: any }) -> (boolean) )?
)
	local seen = {}
	
	local function recurse(node: { [any]: any }, path: { any })
		if seen[node] then
			return -- avoid issues with cyclic table references
		end
		seen[node] = true
		
		for key, value in pairs(node) do
			path[#path + 1] = key

			if typeof(value) == "table" then
				if not shouldVisit or shouldVisit(key, value, path, node) then
					recurse(value, path)
				end
			elseif not shouldVisit or shouldVisit(key, value, path, node) then
				onVisit(key, value, path, node)
			end

			path[#path] = nil
		end
	end

	recurse(sourceTbl, {})
end

-- Checks whether the provided table has any duplicate values.
-- <strong>value</strong>: Optionally check a specific value for duplication.
function Module.containsDuplicates(source: { [any]: any }, value: any?): boolean
	if value ~= nil then
		-- Only count occurrences of value
		local count = 0
		for _, value in pairs(source) do
			if value == value then
				count += 1
				if count >= 2 then
					return true
				end
			end
		end
		return false
	else
		-- Check for any duplicate across all values
		local seenValues: { [any]: boolean } = {}
		for _, value in pairs(source) do
			if seenValues[value] then
				return true
			end
			seenValues[value] = true
		end
		return false
	end
end

do
	local function createLookupSet<T>(tbl: { [any]: T }): { [T]: boolean }
		local set = {}
		for _, value in tbl do
			set[value] = true
		end
		return set
	end
	
	--[[
		Returns true if any value in <strong>checkTable</strong> exists in <strong>baseTable</strong>
	]]
	function Module.containsAny(baseArray: { [any]: any }, checkTable: { [any]: any }): boolean
		local lookup = createLookupSet(baseArray)

		for _, value in checkTable do
			if lookup[value] then
				return true
			end
		end

		return false
	end
end

-- Grabs a random key/index pair out of the given table.
function Module.random<K>(source: { [K]: any }, rngOverride: Random?): (K?)
	assert(type(source) == "table", "First argument must be a table")
	local random = if typeof(rngOverride) == "Random" then rngOverride else rng

	-- array case
	local len = #source
	if len > 0 then
		return random:NextInteger(1, len) :: any
	end

	-- dictionary case
	local keyArray = Keys(source)
	if #keyArray == 0 then
		return nil
	end
	return keyArray[random:NextInteger(1, #keyArray)]
end

do
	local sortCache = Module.weakCache("k")

	--[[
		Adds caching to table.sort()
		This caches the results if the input array and comparator are the same and returns a shallow copy of the cached results.
		Do not use if the input array is frequently mutated during runtime
	]]
	function Module.sortCached<T>(
		array: { T },
		comparator: (a: T, b: T) -> boolean
	): { T }
		assert(typeof(array) == "table", "Expected a table")
		assert(typeof(comparator) == "function", "Expected a comparator function")
		local cacheForTable = sortCache[array]
		if cacheForTable then
			local cached = cacheForTable[comparator]
			if cached then
				return cached
			end
		else
			cacheForTable = Module.weakCache("k")
			sortCache[array] = cacheForTable
		end

		local copy = table.clone(array)
		table.sort(copy, comparator)
		cacheForTable[comparator] = copy
		return copy
	end
end

Module.copy = Copy
Module.sync = Sync
Module.reconcile = Reconcile
Module.swapRemove = SwapRemove
Module.swapRemoveFirstValue = SwapRemoveFirstValue
Module.map = Map
Module.filter = Filter
Module.reduce = Reduce
Module.assign = Assign
Module.extend = Extend
Module.reverse = Reverse
Module.shuffle = Shuffle
Module.sample = Sample
Module.flat = Flat
Module.flatMap = FlatMap
Module.keys = Keys
Module.values = Values
Module.find = Find
Module.every = Every
Module.some = Some
Module.truncate = Truncate
Module.zip = Zip
Module.lock = Lock
Module.isEmpty = IsEmpty
Module.encodeJSON = EncodeJSON
Module.decodeJSON = DecodeJSON

return Module