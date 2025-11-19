--!strict
local Module = {}

local UserInputService = game:GetService("UserInputService")

local KEYCODE_INT_MAP = {
	[0] = Enum.KeyCode.Zero,
	[1] = Enum.KeyCode.One,
	[2] = Enum.KeyCode.Two,
	[3] = Enum.KeyCode.Three,
	[4] = Enum.KeyCode.Four,
	[5] = Enum.KeyCode.Five,
	[6] = Enum.KeyCode.Six,
	[7] = Enum.KeyCode.Seven,
	[8] = Enum.KeyCode.Eight,
	[9] = Enum.KeyCode.Nine
}
local KEY_CODE_REPLACEMENTS = {
	[Enum.KeyCode.Space] = "Spacebar",
	[Enum.KeyCode.LeftShift] = "LShift",
	[Enum.KeyCode.RightShift] = "RShift",
	[Enum.KeyCode.LeftControl] = "LCtrl",
	[Enum.KeyCode.RightControl] = "RCtrl",
	[Enum.KeyCode.LeftAlt] = "LAlt",
	[Enum.KeyCode.RightAlt] = "RAlt",
}

--[[
	Returns a generic finger touch image; good for proximity prompts.
]]
function Module.getPromptTouchIconId(): string
	return "rbxassetid://7158102700"
end

-- Grabs a string that represents the keycode with some shortened strings for specific strings.
-- This is an artistic preference.
function Module.getStringForKeyCode(keyCode: Enum.KeyCode): string
	-- Use shortened/modified version for a few of the keycodes, this is simply artistic preference
	if KEY_CODE_REPLACEMENTS[keyCode] then
		return KEY_CODE_REPLACEMENTS[keyCode]
	end

	-- Get the correct string to display for the keycode. This allows us to display the
	-- correct key for non-QWERTY keyboard layouts.
	local str = UserInputService:GetStringForKeyCode(keyCode)
	-- If there is no defined string for the keycode, simply return the keycode name
	if str == "" then
		return keyCode.Name
	else
		return str
	end
end

-- Returns a string image id for the keycode.
function Module.getImageForKeyCode(keyCode: Enum.KeyCode): string
	return UserInputService:GetImageForKeyCode(keyCode)
end

-- Returns the number keycode (keys 1-9 & 0) for the given integer, or unknown
function Module.getKeycodeFromInteger(integer: number): Enum.KeyCode
	local keycode = KEYCODE_INT_MAP[integer]
	if keycode then
		return keycode
	end
	return Enum.KeyCode.Unknown
end

return Module