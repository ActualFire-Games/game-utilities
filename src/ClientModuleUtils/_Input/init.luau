--!strict
-- Slightly modified versin of Sleitnick's input module
-- https://github.com/Sleitnick/RbxUtil

local _Gamepad = require(script._Gamepad)
local _Mouse = require(script._Mouse)
local _Keyboard = require(script._Keyboard)
local _PreferredInput = require(script._PreferredInput)
local _Touch = require(script._Touch)

export type GamepadType = _Gamepad.GamepadType
export type MouseType = _Mouse.MouseType
export type KeyboardType = _Keyboard.KeyboardType
export type TouchType = _Touch.TouchType

return {
	Gamepad = _Gamepad,
	Mouse = _Mouse,
	Keyboard = _Keyboard,
	PreferredInput = _PreferredInput,
	Touch = _Touch
}