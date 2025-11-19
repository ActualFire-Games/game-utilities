--!strict
--@author: crusherfire
--@date: 7/11/25
--[[@description:
	Utilities specifically for thread recycling.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local t = require("./_t")

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}

local MAX_POOL_SIZE = 50
local freeThreads: { thread } = table.create(MAX_POOL_SIZE)

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- Runs the user callback, catches errors, then returns the thread to the pool.
local function runCallback(callback, thread, ...)
	local success, err = xpcall(callback, debug.traceback, ...)
	if not success then
		warn(err)
	end

	if #freeThreads < MAX_POOL_SIZE then
		table.insert(freeThreads, thread)
	end
end

local function threadWorker()
	while true do
		runCallback(coroutine.yield())
	end
end

-- Grabs a thread from the pool or creates a fresh one.
local function getPooledThread(): thread
	local thread: any
	repeat
		thread = table.remove(freeThreads)
		if thread and coroutine.status(thread) == "suspended" then
			return thread
		end
	until not thread

	thread = coroutine.create(threadWorker)
	coroutine.resume(thread)
	return thread
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Fast-defer that reuses threads.
function Module.defer<T...>(callback: (T...) -> (), ...: T...): thread
	assert(t.callback(callback))
	local thread = getPooledThread()
	return task.defer(thread, callback, thread, ...)
end

-- Fast-spawn that reuses threads.
function Module.spawn<T...>(callback: (T...) -> (), ...: T...): thread
	assert(t.callback(callback))
	local thread = getPooledThread()
	return task.spawn(thread, callback, thread, ...)
end

-- Fast-delay that reuses threads.
function Module.delay<T...>(delayTime: number, callback: (T...) -> (), ...: T...): thread
	assert(t.number(delayTime))
	assert(t.callback(callback))
	local thread = getPooledThread()
	return task.delay(delayTime, thread, callback, thread, ...)
end

-----------------------------
-- MAIN --
-----------------------------
return Module