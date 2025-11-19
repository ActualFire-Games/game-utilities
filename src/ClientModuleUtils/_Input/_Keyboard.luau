--!strict
-- Keyboard
-- Stephen Leitnick
-- October 10, 2021
local ModuleUtils = require(script.Parent.Parent.Parent.ModuleUtils)

local Trove = ModuleUtils.Trove
local Signal = ModuleUtils.Signal

local UserInputService = game:GetService("UserInputService")

--[=[
	@class Keyboard
	@client

	The Keyboard class is part of the Input package.

	```lua
	local Keyboard = require(packages.Input).Keyboard
	```
]=]
local Keyboard = {}
Keyboard.__index = Keyboard
type self = {
	_trove: ModuleUtils.TroveType,
	KeyDown: ModuleUtils.SignalType<(key: Enum.KeyCode, wasProcessed: boolean) -> (), (Enum.KeyCode, boolean)>,
	KeyUp: ModuleUtils.SignalType<(key: Enum.KeyCode, wasProcessed: boolean) -> (), (Enum.KeyCode, boolean)>
}
export type KeyboardType = typeof(setmetatable({} :: self, Keyboard))

--[=[
	@within Keyboard
	@prop KeyDown Signal<Enum.KeyCode>
	@tag Event
	Fired when a key is pressed.
	```lua
	keyboard.KeyDown:Connect(function(key: KeyCode)
		print("Key pressed", key)
	end)
	```
]=]
--[=[
	@within Keyboard
	@prop KeyUp Signal<Enum.KeyCode>
	@tag Event
	Fired when a key is released.
	```lua
	keyboard.KeyUp:Connect(function(key: KeyCode)
		print("Key released", key)
	end)
	```
]=]

--[=[
	@return Keyboard

	Constructs a new keyboard input capturer.

	```lua
	local keyboard = Keyboard.new()
	```
]=]
function Keyboard.new(): KeyboardType
	local self = setmetatable({}, Keyboard)
	self._trove = Trove.new()
	self.KeyDown = self._trove:Construct(Signal)
	self.KeyUp = self._trove:Construct(Signal)
	self:_setup()
	return self
end

--[=[
	Check if the given key is down.

	```lua
	local w = keyboard:IsKeyDown(Enum.KeyCode.W)
	if w then ... end
	```
]=]
function Keyboard:IsKeyDown(keyCode: Enum.KeyCode): boolean
	return UserInputService:IsKeyDown(keyCode)
end

--[=[
	Check if _both_ keys are down. Useful for key combinations.

	```lua
	local shiftA = keyboard:AreKeysDown(Enum.KeyCode.LeftShift, Enum.KeyCode.A)
	if shiftA then ... end
	```
]=]
function Keyboard:AreKeysDown(keyCodeOne: Enum.KeyCode, keyCodeTwo: Enum.KeyCode): boolean
	return (self:IsKeyDown(keyCodeOne) and self:IsKeyDown(keyCodeTwo)) :: boolean
end

--[=[
	Check if _either_ of the keys are down. Useful when two keys might perform
	the same operation.

	```lua
	local wOrUp = keyboard:AreEitherKeysDown(Enum.KeyCode.W, Enum.KeyCode.Up)
	if wOrUp then
		-- Go forward
	end
	```
]=]
function Keyboard:AreEitherKeysDown(keyCodeOne: Enum.KeyCode, keyCodeTwo: Enum.KeyCode): boolean
	return self:IsKeyDown(keyCodeOne) or self:IsKeyDown(keyCodeTwo)
end

function Keyboard:_setup()
	self._trove:Connect(UserInputService.InputBegan, function(input, processed)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			self.KeyDown:Fire(input.KeyCode, processed)
		end
	end)

	self._trove:Connect(UserInputService.InputEnded, function(input, processed)
		if input.UserInputType == Enum.UserInputType.Keyboard then
			self.KeyUp:Fire(input.KeyCode, processed)
		end
	end)
end

--[=[
	Destroy the keyboard input capturer.
]=]
function Keyboard:Destroy()
	self._trove:Destroy()
end

return Keyboard