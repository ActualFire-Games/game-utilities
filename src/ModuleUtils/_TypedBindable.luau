--!strict

type Signal<T...> = {
	Connect: (self: Signal<T...>, fn: (T...) -> ()) -> RBXScriptConnection,
	ConnectParallel: (self: Signal<T...>, fn: (T...) -> ()) -> RBXScriptConnection,
	Once: (self: Signal<T...>, fn: (T...) -> ()) -> RBXScriptConnection,
	Wait: (self: Signal<T...>) -> T...,
}

--[=[
	@within TypedRemote
	@interface Event<T...>
	.OnClientEvent Signal<T...>,
	.OnServerEvent PlayerSignal<T...>,
	.FireClient (self: Event<T...>, player: Player, T...) -> (),
	.FireAllClients (self: Event<T...>, T...) -> (),
	.FireServer (self: Event<T...>, T...) -> (),
]=]
export type Event<T...> = Instance & {
	Event: Signal<T...>,
	Fire: (self: Event<T...>, T...) -> (),
}

--[=[
	@within TypedRemote
	@interface Function<T..., R...>
	.InvokeServer (self: Function<T..., R...>, T...) -> R...,
	.OnServerInvoke (player: Player, T...) -> R...,
]=]
export type Function<T..., R...> = Instance & {
	Invoke: (self: Function<T..., R...>, T...) -> R...,
	OnInvoke: (T...) -> R...,
}

local TypedBindable = {}

--[=[
	@return ((name: string) -> BindableFunction, (name: string) -> BindableEvent)

	Creates a memoized version of the `func` and `event` functions that include the `parent`
	in each call.

	```lua
	-- Create RF and RE functions that use the current script as the instance parent:
	local RF, RE = TypedRemote.parent(script)

	local remoteFunc = RF("RemoteFunc")
	```
]=]
function TypedBindable.parent(parent: Instance)
	return function(name: string)
		return TypedBindable.func(name, parent)
	end, function(name: string)
		return TypedBindable.event(name, parent)
	end
end

--[=[
	Creates a BindableFunction with `name` and parents it inside of `parent`.
	
	If the `parent` argument is not included or is `nil`, then it defaults to the parent of
	this TypedRemote ModuleScript.
]=]
function TypedBindable.func(name: string, parent: Instance): BindableFunction
	local rf: BindableFunction
	rf = Instance.new("BindableFunction")
	rf.Name = name
	rf.Parent = if parent then parent else script
	return rf
end

--[=[
	Creates a BindableEvent with `name` and parents it inside of `parent`.
	
	If the `parent` argument is not included or is `nil`, then it defaults to the parent of
	this TypedRemote ModuleScript.
]=]
function TypedBindable.event(name: string, parent: Instance?): BindableEvent
	local re: BindableEvent
	re = Instance.new("BindableEvent")
	re.Name = name
	re.Parent = if parent then parent else script
	return re
end

table.freeze(TypedBindable)

return TypedBindable