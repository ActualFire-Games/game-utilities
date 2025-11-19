--!optimize 2
--!strict
--!native

-- LemonSignal
-- https://github.com/Data-Oriented-House/LemonSignal

local freeThreads: { thread } = {}

local function runCallback(callback, thread, ...)
	callback(...)
	table.insert(freeThreads, thread)
end

local function yielder()
	while true do
		runCallback(coroutine.yield())
	end
end

local Connection = {}
Connection.__index = Connection
type self = {
	Connected: boolean,
	_signal: any,
	_next: any,
	_prev: any,
}
export type SignalConnection = typeof(setmetatable({} :: self, Connection))

local function disconnect(self: SignalConnection)
	if not self.Connected then
		return
	end
	self.Connected = false

	local next = self._next
	local prev = self._prev

	if next then
		next._prev = prev
	end
	if prev then
		prev._next = next
	end

	local signal = self._signal
	if signal._head == self then
		signal._head = next
	end
end

local function reconnect(self: SignalConnection)
	if self.Connected then
		return
	end
	self.Connected = true

	local signal = self._signal
	local head = signal._head
	if head then
		head._prev = self
	end
	signal._head = self

	self._next = head
	self._prev = false
end

Connection.Disconnect = disconnect
Connection.Reconnect = reconnect

--\\ Signal //--
local Signal = {} --:: SignalTable
Signal.__index = Signal

export type Signal<T...> = {
	RBXScriptConnection: RBXScriptConnection?,

	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> SignalConnection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> SignalConnection,
	Wait: (self: Signal<T...>) -> T...,
	Fire: (self: Signal<T...>, T...) -> (),
	FireDefer: (self: Signal<T...>, T...) -> (),
	DisconnectAll: (self: Signal<T...>) -> (),
	Destroy: (self: Signal<T...>) -> (),
}

export type SignalType<Func, T...> = {
	RBXScriptConnection: RBXScriptConnection?,

	Fire: (self: SignalType<Func, T...>, T...) -> (),
	FireDefer: (self: SignalType<Func, T...>, T...) -> (),
	Connect: (self: SignalType<Func, T...>, fn: Func) -> SignalConnection,
	Once: (self: SignalType<Func, T...>, fn: Func) -> SignalConnection,
	Wait: (self: SignalType<Func, T...>) -> T...,
	DisconnectAll: (self: SignalType<Func, T...>) -> (),
	Destroy: (self: SignalType<Func, T...>) -> ()
}

export type GenericSignal = Signal<>

-- stylua: ignore
local rbxConnect, rbxDisconnect do
	if task then
		local bindable = Instance.new("BindableEvent")
		rbxConnect = bindable.Event.Connect
		rbxDisconnect = bindable.Event:Connect(function() end).Disconnect
		bindable:Destroy()
	end
end

local function connect(self: any, fn: any, ...: any)
	local head = self._head
	local varargs = { ... }
	local cn = setmetatable({
		Connected = true,
		_signal = self,
		_fn = fn,
		_varargs = if #varargs == 0 then false else varargs,
		_next = head,
		_prev = false,
	}, Connection)

	if head then
		head._prev = cn
	end
	self._head = cn

	return cn
end

local function once(self, fn, ...)
	local cn
	cn = connect(self :: any, function(...)
		disconnect(cn)
		fn(...)
	end, ...)
	return cn
end

local function wait(self)
	local thread = coroutine.running()
	local cn
	cn = connect(self :: any, function(...)
		disconnect(cn)
		self._waiting[thread] = nil
		if coroutine.status(thread) == "suspended" then
			task.spawn(thread, ...)
		end
	end)
	self._waiting[thread] = true
	return coroutine.yield()
end

-- Fires the signal and resumes connections immediately via <code>task.spawn()</code>.
-- Please transition to <code>:FireDefer()</code> instead to continue adopting the new deferred signaling model.
local function fire<Func, T...>(self: any, ...: any)
	local cn = self._head
	while cn do
		local thread
		if #freeThreads > 0 then
			thread = freeThreads[#freeThreads]
			freeThreads[#freeThreads] = nil
		else
			thread = coroutine.create(yielder)
			coroutine.resume(thread)
		end

		if not cn._varargs then
			task.spawn(thread, cn._fn, thread, ...)
		else
			local args = cn._varargs
			local len = #args
			local count = len
			local newArgs = table.pack(...) -- Use table.pack to pack the variadic arguments (resolves type error)
			for i = 1, newArgs.n do
				count += 1
				args[count] = newArgs[i]
			end

			task.spawn(thread, cn._fn, thread, table.unpack(args))

			for i = count, len + 1, -1 do
				args[i] = nil
			end
		end

		cn = cn._next
	end
end

-- Fires the signal and resumes connections via <code>task.defer()</code>.
local function fireDefer<Func, T...>(self: any, ...: any)
	task.defer(function(...)
		local cn = self._head
		while cn do
			local thread
			if #freeThreads > 0 then
				thread = freeThreads[#freeThreads]
				freeThreads[#freeThreads] = nil
			else
				thread = coroutine.create(yielder)
				coroutine.resume(thread)
			end

			if not cn._varargs then
				task.spawn(thread, cn._fn, thread, ...)
			else
				local args = cn._varargs
				local len = #args
				local count = len
				local newArgs = table.pack(...)
				for i = 1, newArgs.n do
					count += 1
					args[count] = newArgs[i]
				end

				task.spawn(thread, cn._fn, thread, table.unpack(args))

				for i = count, len + 1, -1 do
					args[i] = nil
				end
			end

			cn = cn._next
		end
	end, ...)
end

local function disconnectAll(self: any)
	local cn = self._head
	while cn do
		disconnect(cn)
		cn = cn._next
	end
end

local function destroy(self: any)
	disconnectAll(self :: any)
	for thread, _ in pairs(self._waiting) do
		if coroutine.status(thread) == "suspended" then
			task.cancel(thread)
		end
		self._waiting[thread] = nil
	end
	local cn = self.RBXScriptConnection
	if cn then
		rbxDisconnect(cn)
		self.RBXScriptConnection = nil
	end
end

--\\ Constructors
function Signal.new(): any
	local self = { _head = false, _waiting = {} }
	setmetatable(self, Signal)

	return self :: any
end

function Signal.wrap(signal: RBXScriptSignal): any
	local wrapper = setmetatable({ _head = false, _waiting = {} }, Signal)

	wrapper.RBXScriptConnection = rbxConnect(signal :: any, function(...)
		fire(wrapper :: any, ...)
	end)

	return wrapper :: any
end

--\\ Methods
Signal.Connect = connect
Signal.Once = once
Signal.Wait = wait
Signal.Fire = fire
Signal.FireDefer = fireDefer
Signal.DisconnectAll = disconnectAll
Signal.Destroy = destroy

return { new = Signal.new, wrap = Signal.wrap }