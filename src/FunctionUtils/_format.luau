--!strict
local t = require("./_t")
type NumeralType = {
	Value: number,
	Numeral: string
}

local suffixes = {"K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg", "Uvg", "Dvg", "Tvg", "Qavg", "Qivg", "Sxvg", "Spvg", "Ocvg"}
local numerals = {
	{Value = 1000, Numeral = "M"},
	{Value = 900, Numeral = "CM"},
	{Value = 500, Numeral = "D"},
	{Value = 400, Numeral = "CD"},
	{Value = 100, Numeral = "C"},
	{Value = 90, Numeral = "XC"},
	{Value = 50, Numeral = "L"},
	{Value = 40, Numeral = "XL"},
	{Value = 10, Numeral = "X"},
	{Value = 9, Numeral = "IX"},
	{Value = 5, Numeral = "V"},
	{Value = 4, Numeral = "IV"},
	{Value = 1, Numeral = "I"},
} :: {NumeralType}

local Module = {}

--[[ 
	Returns the possessive form of a given name.
	If the name ends in "s" (case-insensitive), appends just an apostrophe.
	Otherwise, appends `'s`.
]]
function Module.getPossessiveName(name: string): string
	assert(typeof(name) == "string", "getPossessiveName(): name must be a string")

	local lastCharacter = string.sub(name, -1)
	if lastCharacter:lower() == "s" then
		return name .. "'"
	end

	return name .. "'s"
end

-- Calls tostring() on input and removes all special characters (except for underscores).
function Module.getAttributeSafeString(input: any): string
	return tostring(input):gsub("[^%w_]", "")
end

--[[
	returns a string with the concat assetid link
	i.e. "rbxassetid://123456789"
]]
function Module.formatAssetLink(id: string | number): string
	assert(t.number(id) or t.string(id), "id must be a string or number")
	return `rbxassetid://{id}`
end

function Module.getRomanNumeral(value: number): string
	local result = ""
	for _, numeral: NumeralType in ipairs(numerals) do
		while value >= numeral.Value do
			value -= numeral.Value
			result ..= numeral.Numeral
		end
	end

	return result
end

-- Formats a number into float with a suffix (if applicable).
-- <strong>precision</strong>: Default is 1 decimal place.
function Module.abbreviateNumber(x: number, precision: number?)
	local precision = precision or 1
	local multiplier = 10 ^ precision

	if x < 1000 then
		return tostring(math.floor(x * multiplier + 0.5) / multiplier)
	end

	local suffixIndex = math.floor(math.log10(x) / 3)
	local suffix = suffixes[suffixIndex]

	if not suffix then
		return tostring(math.floor(x * multiplier + 0.5) / multiplier)
	end

	local divisor = 10 ^ (suffixIndex * 3)
	local shortValue = x / divisor

	local roundedValue = math.floor(shortValue * multiplier + 0.5) / multiplier

	-- If rounding pushes the value to 1000, switch to next suffix
	if roundedValue >= 1000 and suffixes[suffixIndex + 1] then
		suffixIndex += 1
		suffix = suffixes[suffixIndex]
		divisor = 10 ^ (suffixIndex * 3)
		roundedValue = math.floor((x / divisor) * multiplier + 0.5) / multiplier
	end

	local formatted = string.format(`%.{precision}f`, roundedValue)
	formatted = formatted:gsub("%.?0+$", "")

	return `{formatted}{suffix}`
end

function Module.removeRichTextTags(input: string): string
	return input:gsub("<[^<>]->", "")
end

-- Formats a number into float with a suffix (if applicable).
-- <strong>precision</strong>: Default is 1 decimal place.
function Module.abbreviateCash(x: number, precision: number?)
	local precision = precision or 1

	if x < 1000 then
		return Module.formatCash(x)
	end

	local suffixIndex = math.floor(math.log10(x) / 3)
	local suffix = suffixes[suffixIndex]

	if not suffix then
		return Module.formatCash(x)
	end

	local divisor = 10 ^ (suffixIndex * 3)
	local shortValue = x / divisor

	local multiplier = 10 ^ precision
	local roundedValue = math.floor(shortValue * multiplier + 0.5) / multiplier

	-- If rounding pushes the value to 1000, switch to next suffix
	if roundedValue >= 1000 and suffixes[suffixIndex + 1] then
		suffixIndex += 1
		suffix = suffixes[suffixIndex]
		divisor = 10 ^ (suffixIndex * 3)
		roundedValue = math.floor((x / divisor) * multiplier + 0.5) / multiplier
	end

	local formatted = string.format(`%.{precision}f`, roundedValue)
	formatted = formatted:gsub("%.?0+$", "")

	return `{formatted}{suffix}`
end

-- Removes all rich text tags from the string, including replacing `\n` breaks with their rich text counterpart.
-- Use this to get an accurate utf8.graphemes count that excludes rich text markup.
function Module.removeTags(str: string): string
	-- replace line break tags (otherwise grapheme loop will miss those linebreak characters)
	str = str:gsub("<br%s*/>", "\n")
	return (str:gsub("<[^<>]->", ""))
end

--[[
	Formats numbers into a 'cash' format.
	100 -> 100
	0.011 -> 0.01
	1000.155 -> 1,000.16
]]
function Module.formatCash(amount: number): string
	assert(typeof(amount) == "number", "FormatCash expects a number")
	-- Round to the nearest cent
	local roundedAmount = math.floor(amount * 100 + 0.5) / 100

	-- Get a two-decimal string
	local formattedString = string.format("%.2f", roundedAmount)

	-- Handle a leading minus-sign
	local isNegative = false
	if formattedString:sub(1, 1) == "-" then
		isNegative = true
		formattedString = formattedString:sub(2)
	end

	-- Split into integer + fractional parts
	local integerPart, fractionalPart =
		formattedString:match("^(%d+)(%.%d%d)$")

	-- Sanity checks in case of unexpected strings
	if not integerPart or not fractionalPart then
		error(`FormatCash failed to parse '{formattedString}'`, 2)
	end

	local integerNumber = tonumber(integerPart)
	if not integerNumber then
		error(`FormatCash invalid integer '{integerPart}'`, 2)
	end

	-- Insert commas, reattach sign, and decide whether to include cents
	local withCommas = Module.formatWithCommas(integerNumber)
	local result = (isNegative and "-" or "") .. withCommas

	if fractionalPart ~= ".00" then
		result = result .. fractionalPart
	end

	return result
end

-- Formats any number to include commas (if applicable).
function Module.formatWithCommas(num: number): string
	local negative = false
	if num < 0 then
		negative = true
		num = -num
	end

	local str = tostring(num)
	local integer, fractional = str:match("^(%d+)(%.%d+)$")
	if not integer then
		integer = str
		fractional = ""
	end

	local reversed = (integer :: string):reverse()
	local parts = {}
	for i = 1, #reversed, 3 do
		parts[#parts + 1] = reversed:sub(i, i + 2)
	end

	local withCommas = table.concat(parts, ","):reverse()
	if negative then
		withCommas = `-{withCommas}`
	end

	return `{withCommas}{fractional}`
end

function Module.nearest2DecimalPlaces(float : number)
	float *= 100
	return (math.floor(float) / 100)
end

--[[
	Formats the duration in seconds to a time string.
	Example: 125 -> 2:05, 3605 -> 1:00:05
	<strong>minUnit</strong>: Default is 'minutes'
]]
function Module.formatTime(seconds: number, minUnit: ("hours" | "minutes" | "seconds")?): string
	assert(typeof(seconds) == "number", "formatTime expects a number")
	local precision = minUnit or "minutes"

	local totalSeconds = math.floor(seconds)
	local hours = math.floor(totalSeconds / 3600)
	local minutes = math.floor((totalSeconds % 3600) / 60)
	local secs = totalSeconds % 60

	local parts = {}

	if precision == "hours" or hours > 0 then
		table.insert(parts, string.format("%02d", hours))
		table.insert(parts, string.format("%02d", minutes))
		table.insert(parts, string.format("%02d", secs))
	elseif precision == "minutes" or minutes > 0 then
		table.insert(parts, tostring(minutes))
		table.insert(parts, string.format("%02d", secs))
	else
		table.insert(parts, tostring(secs))
	end

	return table.concat(parts, ":")
end

--[[
	Formats the duration in seconds to a time string (including milliseconds).
	Example: 125.3559 -> 2:05.356, 3605.15 -> 1:00:05.150
	<strong>precision</strong>: How many decimal places. Any missing spaces will be filled with zeros. Must be value of 0-3.
	<strong>minUnit</strong>: Default is 'minutes'
]]
function Module.formatTimeWithMilliseconds(timeInSeconds: number, precision: number, minUnit: "hours" | "minutes" | "seconds"?): string
	assert(typeof(timeInSeconds) == "number", "Expected number for timeInSeconds")
	assert(typeof(precision) == "number" and precision >= 0 and precision <= 3, "Precision must be between 0 and 3")

	local base = Module.formatTime(timeInSeconds, minUnit)

	if precision == 0 then
		return base
	end

	local factor = 10 ^ precision
	local fraction = timeInSeconds % 1
	local fractionalRounded = math.floor(fraction * factor + 0.5)
	return base .. string.format(`.%0{precision}d`, fractionalRounded)
end

-- Attempts to convert a string to PascalCase
-- Examples:
-- HELLOTHERE -> Hellothere
-- hello_there -> HelloThere
function Module.toPascalCase(input: string): string
	local parts = {}
	-- iterate over runs of letters and digits (ignore underscores, punctuation, etc.)
	for word in string.gmatch(input, "[A-Za-z0-9]+") do
		local firstChar = string.sub(word, 1, 1)
		local rest = string.sub(word, 2)
		-- uppercase the first letter, lowercase the rest
		local capitalized = string.upper(firstChar) .. string.lower(rest)
		table.insert(parts, capitalized)
	end
	return table.concat(parts)
end

-- Get the correspending ordinal suffix for a number returns as a string. It accounts for 11 - 13
-- Examples:
-- 1 -> 1st
-- 11 -> 11th
function Module.getOrdinalString(input: number): string
	local suffix = "th"
	if input % 100 < 11 or input % 100 > 13 then
		local lastDigit = input % 10
		if lastDigit == 1 then
			suffix = "st"
		elseif lastDigit == 2 then
			suffix = "nd"
		elseif lastDigit == 3 then
			suffix = "rd"
		end
	end
	return tostring(input) .. suffix
end

function Module.getNumberFromOrdinal(ordinal: string): number?
	local num = string.match(ordinal, "%d+")
	return if num then tonumber(num) else nil
end

-- Simply adds a space before an uppercase letter
-- Input: HelloWorld
-- Output: Hello World
function Module.addSpaceBeforeUpperCase(input: string): string
	return input:gsub("(%u)", " %1"):gsub("^ ", "")
end

--Separates all strings by uppercase and inserts into a table.
function Module.splitByUppercase(input: string): {string}
	local result = {}
	for word in input:gmatch("[A-Z][^A-Z]*") do
		table.insert(result, word)
	end
	return result
end

-- RICH TEXT UTILITIES --
do
	export type FontOptions = {
		Color: Color3 | string?,
		Size: number?,
		Face: string?,
	}

	export type StrokeOptions = {
		Color: Color3 | string?,
		Thickness: number?,
		Transparency: number?,
	}

	-- Escapes characters that would break markup.
	function Module.escapeRichText(text: string | number): string
		local escaped = tostring(text)
		escaped = escaped:gsub("&", "&amp;")
		escaped = escaped:gsub("<", "&lt;")
		escaped = escaped:gsub(">", "&gt;")
		return escaped
	end

	-- Convert Color3 into a #RRGGBB string.
	function Module.color3ToHex(color: Color3): string
		assert(typeof(color) == "Color3", "color3ToHex expects Color3")
		local r = math.floor(color.R * 255 + 0.5)
		local g = math.floor(color.G * 255 + 0.5)
		local b = math.floor(color.B * 255 + 0.5)
		return string.format("#%02X%02X%02X", r, g, b)
	end

	-- Normalizes a color input to a hex string acceptable by RichText.
	local function normalizeColor(color: Color3 | string): string
		if typeof(color) == "Color3" then
			return Module.color3ToHex(color)
		end

		if typeof(color) == "string" then
			-- Accept both #RGB and #RRGGBB. Leave other strings untouched.
			return color
		end

		error("normalizeColor: color must be Color3 or hex string", 2)
	end

	-- Generic rich text tag wrapper.
	function Module.wrapTag(tag: string, text: string | number, attributes: { [string]: string }?)
		assert(t.tuple(t.string, t.union(t.string, t.number), t.optional(t.map(t.string, t.string)))(tag, text, attributes))

		local attributeString = ""
		if attributes then
			local parts = {}
			for key, value in pairs(attributes) do
				local safeKey = Module.getAttributeSafeString(key)
				local asString = tostring(value)
				-- Quote attribute values to be safe
				parts[#parts + 1] = string.format(" %s=\"%s\"", safeKey, asString)
			end
			attributeString = table.concat(parts)
		end

		return string.format("<%s%s>%s</%s>", tag, attributeString, tostring(text), tag)
	end
	
	--[[
		Wraps the given text with bold rich text tags.
	]]
	function Module.wrapBold(text: string | number): string
		return Module.wrapTag("b", text)
	end

	--[[
		Wraps the given text with italic rich text tags.
	]]
	function Module.wrapItalic(text: string | number): string
		return Module.wrapTag("i", text)
	end

	--[[
		Wraps the given text with underline rich text tags.
	]]
	function Module.wrapUnderline(text: string | number): string
		return Module.wrapTag("u", text)
	end

	--[[
		Wraps the given text with strikethrough rich text tags.
	]]
	function Module.wrapStrikethrough(text: string | number): string
		return Module.wrapTag("s", text)
	end
	
	--[[
		Wraps the given text with font rich text tags.
	]]
	function Module.wrapFont(text: string | number, options: FontOptions?): string
		local attributes: {[string]: string} = {}

		if options then
			if options.Color then
				attributes.color = normalizeColor(options.Color)
			end
			if options.Size then
				attributes.size = tostring(options.Size)
			end
			if options.Face then
				attributes.face = tostring(options.Face)
			end
		end

		return Module.wrapTag("font", text, attributes)
	end

	--[[
		Wraps the given text with color rich text tags.
	]]
	function Module.wrapColor(text: string | number, color: Color3 | string): string
		local normalized = normalizeColor(color)
		return Module.wrapTag("font", text, { color = normalized })
	end
	
	--[[
		Wraps the given text with text size rich text tags.
	]]
	function Module.wrapSize(text: string | number, size: number): string
		return Module.wrapTag("font", text, { size = tostring(size) })
	end
	
	--[[
		Wraps the given text with font face rich text tags.
	]]
	function Module.wrapFace(text: string | number, face: string): string
		return Module.wrapTag("font", text, { face = face })
	end
	
	--[[
		Wraps the given text with stroke rich text tags.
	]]
	function Module.wrapStroke(text: string | number, options: StrokeOptions?): string
		local attributes: {[string]: string} = {}

		if options then
			if options.Color then
				attributes.color = normalizeColor(options.Color)
			end
			if options.Thickness then
				attributes.thickness = tostring(options.Thickness)
			end
			if options.Transparency then
				attributes.transparency = tostring(options.Transparency)
			end
		end

		return Module.wrapTag("stroke", text, attributes)
	end

	-- Returns the RichText line break tag.
	function Module.br(): string
		return "<br/>"
	end

	--[[
		Compose multiple rich text wrappers into a single wrapper.
	]]
	function Module.composeWrappers(wrappers: {(text: string | number) -> string}): (text: string | number) -> string
		assert(typeof(wrappers) == "table", "compose: wrappers must be an array of functions")

		-- Make a shallow copy so callers can't mutate the internal sequence later.
		local chain = table.create(#wrappers)
		for i = 1, #wrappers do
			chain[i] = wrappers[i]
		end

		return function(text: string | number): string
			local result = tostring(text)
			for _, wrap in ipairs(chain) do
				result = wrap(result)
			end
			return result
		end
	end
end

return Module