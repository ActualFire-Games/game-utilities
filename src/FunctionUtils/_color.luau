--!strict
--@author: crusherfire
--@date: 5/26/25
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

--[[
	Adjusts the saturation of the color.
	<strong>amount</strong>: Value between 0-1 representing target saturation. (0 == no change, 1 == fully saturated)
]]
function Module.saturate(color: Color3, amount: number): Color3
	assert(t.tuple(t.Color3, t.numberConstrained(0, 1))(color, amount))

	local h, s, v = color:ToHSV()
	local newSaturation = math.clamp(s + (1 - s) * amount, 0, 1)
	return Color3.fromHSV(h, newSaturation, v)
end

--[[
	Adjusts the saturation of the color.
	<strong>amount</strong>: Value between 0-1 representing target saturation. (0 == no change, 1 == fully desaturated)
]]
function Module.desaturate(color: Color3, amount: number): Color3
	assert(t.tuple(t.Color3, t.numberConstrained(0, 1))(color, amount))

	local h, s, v = color:ToHSV()
	local newSaturation = math.clamp(s * (1 - amount), 0, 1)
	return Color3.fromHSV(h, newSaturation, v)
end

--[[
	Sets saturation to zero.
	Useful for disabled/inactive UI states.
]]
function Module.grayscale(color: Color3): Color3
	assert(t.Color3(color))

	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, 0, v)
end

-- Offsets the value in the HSV of the color. Values are represented as 0-255.
function Module.offsetValue(color: Color3, value: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, v + (value/255))
end

-- Multiplies the value in the HSV of the color.
function Module.multiplyValue(color: Color3, multiplier: number): Color3
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, v * multiplier)
end

--[[
	Rotates the hue by the specified degrees (0-360).
]]
function Module.adjustHue(color: Color3, degrees: number): Color3
	assert(t.tuple(t.Color3, t.number)(color, degrees))

	local h, s, v = color:ToHSV()
	local newHue = (h + (degrees / 360)) % 1
	return Color3.fromHSV(newHue, s, v)
end

--[[
	Returns the complementary color (opposite on the color wheel).
]]
function Module.getComplementary(color: Color3): Color3
	assert(t.Color3(color))
	return Module.adjustHue(color, 180)
end

--[[
	Attempts to lighten the given color by the provided amount.
	<strong>amount</strong>: Value between 0-1 representing how much to lighten. (0 == no change, 1 == max lighten)
]]
function Module.lighten(color: Color3, amount: number): Color3
	assert(t.tuple(t.Color3, t.numberConstrained(0, 1))(color, amount))
	
	local h, s, v = color:ToHSV()
	-- Clamp ensures we don’t exceed 1.0
	local newValue = math.clamp(v + (1 - v) * amount, 0, 1)
	return Color3.fromHSV(h, s, newValue)
end

--[[
	Attempts to darken the given color by the provided amount.
	<strong>amount</strong>: Value between 0-1 representing how much to lighten. (0 == no change, 1 == max darken)
]]
function Module.darken(color: Color3, amount: number): Color3
	assert(t.tuple(t.Color3, t.numberConstrained(0, 1))(color, amount))

	local h, s, v = color:ToHSV()
	-- Move the value towards 0 (darkness)
	local newValue = math.clamp(v * (1 - amount), 0, 1)
	return Color3.fromHSV(h, s, newValue)
end

--[[
	Blends the color towards pure white.
	<strong>alpha</strong>: Value between 0-1 representing how much to whiten. (0 == no change, 1 == fully white)
]]
function Module.whiten(color: Color3, alpha: number)
	assert(t.tuple(t.Color3, t.numberConstrained(0, 1))(color, alpha))
	local r, g, b = color.R, color.G, color.B
	local newR = r + (1 - r) * alpha
	local newG = g + (1 - g) * alpha
	local newB = b + (1 - b) * alpha

	return Color3.new(newR, newG, newB)
end

--[[
	Blends the color towards pure black.
	<strong>alpha</strong>: Value between 0-1 representing how much to blacken. (0 == no change, 1 == fully black)
]]
function Module.blacken(color: Color3, alpha: number): Color3
	assert(t.tuple(t.Color3, t.numberConstrained(0, 1))(color, alpha))

	local r, g, b = color.R, color.G, color.B
	local newR = r * (1 - alpha)
	local newG = g * (1 - alpha)
	local newB = b * (1 - alpha)

	return Color3.new(newR, newG, newB)
end

--[[
	Blends <code>colorA</code> to <code>colorB</code> through linear interpolation.
]]
function Module.blend(colorA: Color3, colorB: Color3, alpha: number): Color3
	assert(t.tuple(t.Color3, t.Color3, t.numberConstrained(0, 1))(colorA, colorB, alpha))

	local r = colorA.R + (colorB.R - colorA.R) * alpha
	local g = colorA.G + (colorB.G - colorA.G) * alpha
	local b = colorA.B + (colorB.B - colorA.B) * alpha

	return Color3.new(r, g, b)
end

--[[
	Inverts the color by subtracting each component from 1.
	Pure white becomes pure black and vice versa.
]]
function Module.invert(color: Color3): Color3
	assert(t.Color3(color))
	return Color3.new(1 - color.R, 1 - color.G, 1 - color.B)
end

--[[
	Calculates the relative luminance (perceived brightness) of a color.
	Returns a value between 0 (black) and 1 (white).
]]
function Module.getLuminance(color: Color3): number
	assert(t.Color3(color))
	-- relative luminance formula
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
end

--[[
	Returns if the color is considered "dark" based on luminance.
	Useful for choosing text color (white text on dark backgrounds).
]]
function Module.isDark(color: Color3): boolean
	assert(t.Color3(color))
	return Module.getLuminance(color) < 0.5
end

-----------------------------
-- MAIN --
-----------------------------
return Module