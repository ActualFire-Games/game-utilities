--!strict
--@author: crusherfire
--@date: 4/24/25
--[[@description:
	For creating proxies that fire a signal when a value is added to the original table.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Signal = require("../ModuleUtils/_Signal")
local _math = require("./_math")

-----------------------------
-- TYPES --
-----------------------------

type CallbackFunc = (origProxy: any, keys: { any }, newValue: any) -> ()
type ProxyUpdatedSignal = Signal.SignalType<CallbackFunc, (any, { any }, any)>

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}

local proxyCache = setmetatable({}, { __mode = "kv" }) -- prevent proxies keeping tables alive
local idGenerator = _math.getIdGenerator()

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function isProxy(value: any): boolean
	if typeof(value) ~= "table" then
		return false
	end
	local mt = getmetatable(value)
	if not mt or not mt.__isproxy then
		return false
	end
	return true
end

local function wrapTable(orig: { [any]: any }, _path: { any }, _head: any?): (any, ProxyUpdatedSignal)
	assert(typeof(orig) == "table", "invalid table")
	-- return already proxied tables
	if proxyCache[orig] then
		local proxy = proxyCache[orig]
		return proxy, getmetatable(proxy).__headSignal
	end

	local proxyId = idGenerator()
	local proxy = {}
	local headProxy = _head or proxy
	local headMt = getmetatable(headProxy)
	local headSignal = if headMt then headMt.__headSignal else Signal.new()
	
	local mt = {}
	-- store the current path so it can be updated later if needed
	mt.__head = headProxy
	mt.__headSignal = headSignal
	mt.__path = _path

	mt.__index = function(self, key)
		local m = getmetatable(self)
		local value = orig[key]
		if typeof(value) == "table" and not proxyCache[value] then
			local newPath = {table.unpack(m.__path)}
			newPath[#newPath + 1] = key
			wrapTable(value, newPath, headProxy)
		end
		-- always return proxies if available
		value = proxyCache[value] or value
		return value
	end
	mt.__newindex = function(self, key, newValue)
		local m = getmetatable(self)
		local newPath = {table.unpack(m.__path)}
		newPath[#newPath + 1] = key

		if isProxy(newValue) then
			--warn("Attempt set proxy as new value. Please use :Get() to retrieve the original table value.\n", debug.traceback())
			newValue = Module.get(newValue)
		elseif proxyCache[newValue] then
			-- update stored path
			local cachedProxy = proxyCache[newValue]
			local mtCached = getmetatable(cachedProxy)
			mtCached.__path = newPath
		elseif typeof(newValue) == "table" then
			-- wrap unproxied table
			wrapTable(newValue, newPath, headProxy)
		end
		-- Store the raw newValue so orig doesn't store any proxies!
		orig[key] = newValue
		mt.__headSignal:Fire(headProxy, newPath, newValue)
	end

	local function iter(tbl: { [any]: any }, key: any): (any, any)
		local k, v = next(tbl, key)
		if k ~= nil and typeof(v) == "table" and not proxyCache[v] then
			local m = getmetatable(proxy :: any)
			local newPath = {table.unpack(m.__path)}
			newPath[#newPath + 1] = k
			wrapTable(v, newPath, headProxy)
		end
		v = proxyCache[v] or v -- always return proxies
		return k, v
	end
	mt.__iter = function()
		return iter, orig, nil
	end
	mt.__tostring = function()
		return `[proxy: {proxyId} for {orig}]`
	end
	mt.__len = function()
		return #orig
	end
	mt.__original = orig
	mt.__isproxy = true

	proxyCache[orig] = setmetatable(proxy, mt)

	return proxy, headSignal
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Create a proxy that updates the original table _t and fires a signal.
-- This signal is fired for all descendant tables that are converted to proxies as well.
-- <strong>You should clean up connections to this signal if the proxy is no longer used!</strong>
function Module.create<T>(tbl: T): (T, ProxyUpdatedSignal)
	assert(typeof(tbl) == "table", "Invalid table")
	return wrapTable(tbl, {}, nil)
end

-- Creates a proxy and automatically calls <code>callback</code> when any values get updated.
-- Returns the proxy and connection
-- <strong>You should clean up the connection if the proxy is no longer used!</strong>
function Module.watch<T>(tbl: T, callback: CallbackFunc): (T, Signal.SignalConnection)
	local proxy, signal = Module.create(tbl)
	local conn = signal:Connect(callback)
	return proxy, conn
end

-- Get the original table from a proxy.
function Module.get<T>(proxy: T): T
	assert(typeof(proxy) == "table", "Invalid table")
	local mt = getmetatable(proxy)
	if mt and mt.__original then
		return mt.__original
	end
	error("Given table is not a proxy!")
end

-- Get the head signal for the proxy.
-- <strong>You should clean up connections to this signal if the proxy is no longer used!</strong>
function Module.getHeadSignal(proxy: any): ProxyUpdatedSignal
	assert(isProxy(proxy), "invalid proxy")
	local mt = getmetatable(proxy)
	return mt.__headSignal
end

Module.isProxy = isProxy

-- Proxy-safe table.insert()
-- Inserts value at end by default
-- The whole array is passed through the proxy's head signal rather than the index-value pair.
function Module.insert(proxy: any, value: any, pos: number?)
	if value == nil then
		value, pos = pos, nil
	end
	assert(isProxy(proxy), "Insert: must pass a proxy")
	local mt = getmetatable(proxy)
	local orig = mt.__original
	local head = mt.__head
	local headSignal = mt.__headSignal
	local pathBase = mt.__path

	if pos then
		table.insert(orig, pos, value)
	else
		table.insert(orig, value)
		pos = #orig
	end

	if typeof(value) == "table" then
		wrapTable(value, {table.unpack(pathBase, 1, #pathBase)}, head)
	end

	headSignal:Fire(head, pathBase, orig)
end

-- Proxy-safe table.remove()
-- The whole array is passed through the proxy's head signal rather than the index-value pair.
function Module.remove(proxy: any, pos: number?): any?
	assert(isProxy(proxy), "Remove: must pass a proxy")
	local mt = getmetatable(proxy)
	local orig = mt.__original
	local head = mt.__head
	local headSignal = mt.__headSignal
	local pathBase = mt.__path
	local removed = table.remove(orig, pos)
	if typeof(removed) == "table" then
		proxyCache[removed] = nil
	end
	headSignal:Fire(head, pathBase, orig)
	return removed
end

-- Proxy-safe table.copy()
-- Returns a proxy
function Module.copy<T>(proxy: T)
	assert(isProxy(proxy), "Copy: must pass a proxy")
	local orig = Module.get(proxy)
	local clone = table.clone(orig :: any)
	return Module.create(clone)
end

-- Proxy safe table.clear()
function Module.clear(proxy: any)
	assert(isProxy(proxy), "Clear: must pass a proxy")
	local mt = getmetatable(proxy)
	local orig = mt.__original
	local head = mt.__head
	local headSignal = mt.__headSignal
	local pathBase = mt.__path

	for k,v in pairs(orig) do
		if typeof(v) == "table" then
			proxyCache[v] = nil
		end
	end

	table.clear(orig)

	-- signal "this table was wiped" listeners see an empty table
	-- keys = pathBase (path to this table), newValue = orig (now empty)
	headSignal:Fire(head, pathBase, orig)
end

-----------------------------
-- MAIN --
-----------------------------
return Module