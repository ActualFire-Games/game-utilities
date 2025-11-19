--!strict
-- Touch
-- Stephen Leitnick
-- March 14, 2021
local ModuleUtils = require(script.Parent.Parent.Parent.ModuleUtils)
local FunctionUtils = require(script.Parent.Parent.Parent.FunctionUtils)

local Trove = ModuleUtils.Trove
local Signal = ModuleUtils.Signal

local UserInputService = game:GetService("UserInputService")

--[=[
	@class Touch
	@client

	The Touch class is part of the Input package.

	```lua
	local Touch = require(packages.Input).Touch
	```
]=]
local Touch = {}
Touch.__index = Touch
type self = {
	_trove: ModuleUtils.TroveType,
	_usingTouchControls: InputObject?,
	TouchTap: ModuleUtils.SignalType<(touchPositions: { Vector2 }, processed: boolean) -> (), ({ Vector2 }, boolean)>,
	TouchTapInWorld: ModuleUtils.SignalType<(position: Vector2, processed: boolean) -> (), ({ Vector2 }, boolean)>,
	TouchMoved: ModuleUtils.SignalType<(touch: InputObject, processed: boolean) -> (), (InputObject, boolean)>,
	TouchLongPress: ModuleUtils.SignalType<(touchPositions: { Vector2 }, state: Enum.UserInputState, processed: boolean) -> (), ({ Vector2 }, Enum.UserInputState, boolean)>,
	TouchPan: ModuleUtils.SignalType<(touchPositions: { Vector2 }, totalTranslation: Vector2, velocity: Vector2, state: Enum.UserInputState, processed: boolean) -> (), ({ Vector2 }, Vector2, Vector2, Enum.UserInputState, boolean)>,
	TouchPinch: ModuleUtils.SignalType<(touchPositions: { Vector2 }, scale: number, velocity: Vector2, state: Enum.UserInputState, processed: boolean) -> (), ({ Vector2 }, number, Vector2, Enum.UserInputState, boolean)>,
	TouchRotate: ModuleUtils.SignalType<(touchPositions: { Vector2 }, rotation: number, velocity: number, state: Enum.UserInputState, processed: boolean) -> (), ({ Vector2 }, number, number, Enum.UserInputState, boolean)>,
	TouchSwipe: ModuleUtils.SignalType<(swipeDirection: Enum.SwipeDirection, numberOfTouches: number, processed: boolean) -> (), (Enum.SwipeDirection, number, boolean)>,
	TouchStarted: ModuleUtils.SignalType<() -> ()>,
	TouchEnded: ModuleUtils.SignalType<() -> ()>,
	TouchEnabledChanged: ModuleUtils.SignalType<() -> ()>,
	
	ThumbstickControlsBegan: ModuleUtils.SignalType<(input: InputObject) -> (), (InputObject)>,
	ThumbstickControlsEnded: ModuleUtils.SignalType<(input: InputObject) -> (), (InputObject)>,
}
export type TouchType = typeof(setmetatable({} :: self, Touch))

--[=[
	@within Touch
	@prop TouchTap Signal<(touchPositions: {Vector2}, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchTap](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchTap).
]=]
--[=[
	@within Touch
	@prop TouchTapInWorld Signal<(position: Vector2, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchTapInWorld](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchTapInWorld).
]=]
--[=[
	@within Touch
	@prop TouchMoved Signal<(touch: InputObject, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchMoved](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchMoved).
]=]
--[=[
	@within Touch
	@prop TouchLongPress Signal<(touchPositions: {Vector2}, state: Enum.UserInputState, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchLongPress](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchLongPress).
]=]
--[=[
	@within Touch
	@prop TouchPan Signal<(touchPositions: {Vector2}, totalTranslation: Vector2, velocity: Vector2, state: Enum.UserInputState, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchPan](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchPan).
]=]
--[=[
	@within Touch
	@prop TouchPinch Signal<(touchPositions: {Vector2}, scale: number, velocity: Vector2, state: Enum.UserInputState, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchPinch](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchPinch).
]=]
--[=[
	@within Touch
	@prop TouchRotate Signal<(touchPositions: {Vector2}, rotation: number, velocity: number, state: Enum.UserInputState, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchRotate](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchRotate).
]=]
--[=[
	@within Touch
	@prop TouchSwipe Signal<(swipeDirection: Enum.SwipeDirection, numberOfTouches: number, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchSwipe](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchSwipe).
]=]
--[=[
	@within Touch
	@prop TouchStarted Signal<(touch: InputObject, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchStarted](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchStarted).
]=]
--[=[
	@within Touch
	@prop TouchEnded Signal<(touch: InputObject, processed: boolean)>
	@tag Event
	Proxy for [UserInputService.TouchEnded](https://developer.roblox.com/en-us/api-reference/event/UserInputService/TouchEnded).
]=]

--[=[
	Constructs a new Touch input capturer.
]=]
function Touch.new(): TouchType
	local self = setmetatable({} :: self, Touch)

	self._trove = Trove.new()
	
	self.TouchTap = self._trove:Construct(Signal.wrap, UserInputService.TouchTap)
	self.TouchTapInWorld = self._trove:Construct(Signal.wrap, UserInputService.TouchTapInWorld)
	self.TouchMoved = self._trove:Construct(Signal.wrap, UserInputService.TouchMoved)
	self.TouchLongPress = self._trove:Construct(Signal.wrap, UserInputService.TouchLongPress)
	self.TouchPan = self._trove:Construct(Signal.wrap, UserInputService.TouchPan)
	self.TouchPinch = self._trove:Construct(Signal.wrap, UserInputService.TouchPinch)
	self.TouchRotate = self._trove:Construct(Signal.wrap, UserInputService.TouchRotate)
	self.TouchSwipe = self._trove:Construct(Signal.wrap, UserInputService.TouchSwipe)
	self.TouchStarted = self._trove:Construct(Signal.wrap, UserInputService.TouchStarted)
	self.TouchEnded = self._trove:Construct(Signal.wrap, UserInputService.TouchEnded)
	self.TouchEnabledChanged = self._trove:Construct(Signal.wrap, UserInputService:GetPropertyChangedSignal("TouchEnabled"))
	
	self.ThumbstickControlsBegan = self._trove:Construct(Signal)
	self.ThumbstickControlsEnded = self._trove:Construct(Signal)
	
	self._trove:Connect(UserInputService.InputBegan, function(input: InputObject, processed)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if self._usingTouchControls then
			-- A finger is already using the touch controls, ignore other fingers
			return
		end
		
		local objects = FunctionUtils.Interface.getGuiObjectsAtPosition(Vector2.new(input.Position.X, input.Position.Y))
		for _, object in ipairs(objects) do
			if object.Name == "DynamicThumbstickFrame" then
				self._usingTouchControls = input
				self.ThumbstickControlsBegan:Fire(input)
				return
			end
		end
	end)
	self._trove:Connect(UserInputService.InputEnded, function(input: InputObject, processed)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		if self._usingTouchControls == input then
			self._usingTouchControls = nil
			self.ThumbstickControlsEnded:Fire(input)
		end
	end)
	
	return self
end

--[=[
	Returns the value of [`UserInputService.TouchEnabled`](https://developer.roblox.com/en-us/api-reference/property/UserInputService/TouchEnabled).
]=]
function Touch:IsTouchEnabled(): boolean
	return UserInputService.TouchEnabled
end

-- Returns a boolean if touch controls (thumb stick) is actively being used. If so, the InputObject responsible is also returned.
function Touch.IsUsingThumbstickControls(self: TouchType): (boolean, InputObject?)
	if self._usingTouchControls then 
		return true, self._usingTouchControls
	else
		return false
	end
end

--[=[
	Destroys the Touch input capturer.
]=]
function Touch:Destroy()
	self._trove:Destroy()
end

return Touch