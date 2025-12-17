local thread = require("../FunctionUtils/_thread")

export type Future<T...> = {
	ValueList: { any }?,
	AfterList: { (T...) -> () },
	YieldList: { thread },
	OnCancelList: { () -> () },
	Cancelled: boolean,
	_evaluateThread: thread?,
	
	IsComplete: typeof(
		-- Returns a boolean indicating whether the Future is complete.
		function(self: Future<T...>): boolean
			return nil :: any
		end
	),
	IsPending: typeof(
		-- Returns a boolean indicating whether the Future is pending.
		function(self: Future<T...>): boolean
			return nil :: any
		end
	),

	Expect: typeof(
		-- Returns the values of the Future if complete, otherwise it errors with the provided message
		function(self: Future<T...>, Message: string): T...
			
		end
	),
	Unwrap: typeof(
		-- Returns the values of the Future if complete, otherwise it errors.
		function(self: Future<T...>): T...
			
		end
	),
	UnwrapOr: typeof(
		-- Returns the values of the Future if complete, otherwise it returns the provided default values.
		function(self: Future<T...>, ...: T...): T...
			
		end
	),
	UnwrapOrElse: typeof(
		-- Returns the values of the Future if complete, otherwise it calls the provided function and returns the values of the Future returned by the function.
		function(self: Future<T...>, Else: () -> T...): T...
			
		end
	),

	After: typeof(
		-- Calls a function with the values a Future completes with after the future is completed.
		function(self: Future<T...>, Callback: (T...) -> ()): (Future<T...>)
			return self
		end
	),
	Await: typeof(
		-- Returns the values of the Future if complete, otherwise it yields the current thread until the Future is completed.
		function(self: Future<T...>): T...
			
		end
	),
	Cancel: typeof(
		-- Attempts to cancel the Future. This will not work if the Future is already complete.
		function(self: Future<T...>)
			
		end
	),
	OnCancel: typeof(
		-- Calls a function when the Future is cancelled.
		function(self: Future<T...>, Callback: () -> ()): Future<T...>
			return self
		end
	),
}
local function IsComplete<T...>(self: Future<T...>): boolean
	return self.ValueList ~= nil
end

local function IsPending<T...>(self: Future<T...>): boolean
	return self.ValueList == nil
end

local function OnCancel<T...>(self: Future<T...>, Callback: () -> ())
	if self.ValueList then
		return self
	end

	if self.Cancelled then
		thread.defer(Callback)
	else
		table.insert(self.OnCancelList, Callback)
	end

	return self
end

local function Expect<T...>(self: Future<T...>, Message: string): T...
	assert(self.ValueList, Message)

	return table.unpack(self.ValueList)
end

local function Unwrap<T...>(self: Future<T...>): T...
	return self:Expect("Attempt to unwrap pending future!")
end

local function UnwrapOr<T...>(self: Future<T...>, ...): T...
	if self.ValueList then
		return table.unpack(self.ValueList)
	else
		return ...
	end
end

local function UnwrapOrElse<T...>(self: Future<T...>, Else: () -> T...): T...
	if self.ValueList then
		return table.unpack(self.ValueList)
	else
		return Else()
	end
end

local function After<T...>(self: Future<T...>, Callback: (T...) -> ())
	if self.Cancelled then
		return self
	end
	
	if self.ValueList then
		thread.defer(Callback, table.unpack(self.ValueList))
	else
		table.insert(self.AfterList, Callback)
	end
	return self
end

local function Await<T...>(self: Future<T...>): T...
	if self.Cancelled then
		error(`Cannot :Await() a cancelled Future`, 2)
	end
	
	if self.ValueList then
		return table.unpack(self.ValueList)
	else
		table.insert(self.YieldList, coroutine.running())

		return coroutine.yield()
	end
end

local function Cancel<T...>(self: Future<T...>)
	if self.ValueList then
		return
	end

	if self.Cancelled then
		return
	end

	self.Cancelled = true

	for _, Callback in self.OnCancelList do
		thread.spawn(Callback)
	end

	self.OnCancelList = {}

	for _, thread in ipairs(self.YieldList) do
		if coroutine.status(thread) == "suspended" then
			task.cancel(thread)
		end
	end

	if self._evaluateThread and coroutine.status(self._evaluateThread) == "suspended" then
		task.cancel(self._evaluateThread)
		self._evaluateThread = nil
	end

	self.AfterList = {}
	self.YieldList = {}
end

-- The given function is called in a new thread, and the Future is completed with the return values of the function.
local function Future<T..., A...>(callback: (A...) -> T..., ...: A...): Future<T...>
	local self: Future<T...> = {
		ValueList = nil,
		AfterList = {},
		YieldList = {},
		OnCancelList = {},

		IsComplete = IsComplete,
		IsPending = IsPending,

		Expect = Expect,
		Unwrap = Unwrap,
		UnwrapOr = UnwrapOr,
		UnwrapOrElse = UnwrapOrElse,
		Cancel = Cancel,
		
		OnCancel = OnCancel,
		After = After,
		Await = Await,
	} :: any

	self._evaluateThread = thread.spawn(function(self: Future<T...>, callback: (A...) -> T..., ...: A...)
		if self.Cancelled then
			return
		end
		
		local ValueList = { callback(...) }
		self.ValueList = ValueList

		-- cancellation is no longer possible
		self.OnCancelList = {}

		for _, Thread in self.YieldList do
			if coroutine.status(Thread) == "suspended" then
				task.spawn(Thread, table.unpack(ValueList))
			end
		end

		for _, Callback in self.AfterList do
			thread.spawn(Callback, table.unpack(ValueList))
		end
		
		self._evaluateThread = nil
	end, self, callback, ...)

	return self
end

-- This constructor wraps the given function and arguments in a pcall.
-- The returned Future will be completed with the return values of the pcall, including the success boolean.
local function Try<T..., A...>(callback: (A...) -> T..., ...: A...): Future<(boolean, T...)>
	return Future(pcall, callback, ...)
end

-- Waits for all futures to complete and returns a future that resolves with an array of their results.
-- Returns an immediately resolved Future if the future array is empty.
local function All(futures: { Future<...any> }): Future<{ { any } }>
	if #futures == 0 then
		return Future(function()
			return {}
		end)
	end
	return Future(function()
		local results = table.create(#futures)
		local completedCount = 0

		local currentThread = coroutine.running()
		local completed = false

		for i, future in ipairs(futures) do
			future:After(function(...)
				if completed then
					return
				end

				results[i] = { ... }

				completedCount += 1
				if completedCount == #futures then
					completed = true
					if coroutine.status(currentThread) == "suspended" then
						task.spawn(currentThread, results)
					end
				end
			end)
		end
		
		if completed then
			return results
		end
		return coroutine.yield()
	end)
end

-- Resolves when any of the given futures resolves.
-- The returned Future completes with the values of the first completed Future.
-- Returns an immediately resolved Future if the future array is empty.
local function Any(futures: { Future<...any> }): Future<...any>
	return Future(function()
		if #futures == 0 then
			-- No futures to wait on, so immediately resolve
			return
		end

		local currentThread = coroutine.running()
		local resolved = false

		for _, future in ipairs(futures) do
			future:After(function(...)
				if resolved then
					return
				end

				resolved = true

				if coroutine.status(currentThread) == "suspended" then
					task.spawn(currentThread, ...)
				end
			end)
		end

		return coroutine.yield()
	end)
end

return {
	new = Future,
	try = Try,
	all = All,
	any = Any,
}