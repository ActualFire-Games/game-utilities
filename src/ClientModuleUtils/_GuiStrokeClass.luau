--!strict
--@author: crusherfire
--@date: 11/21/24
--[[@description:
	Adds extra features to the UIStroke instance.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local ModuleUtils = require("../ModuleUtils")

-----------------------------
-- TYPES --
-----------------------------
-- For all of the properties/fields of an object made from this class.
type fields = {
	_trove: ModuleUtils.TroveType,
	_scaleTrove: ModuleUtils.TroveType,
	_stroke: UIStroke,
	_usingScale: boolean,
}

-----------------------------
-- VARIABLES --
-----------------------------
local GuiStrokeClass = {}
local MT = {}
MT.__index = MT
export type WrappedUiStroke = typeof(setmetatable({} :: fields, MT))

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function GuiStrokeClass.new(stroke: UIStroke): WrappedUiStroke
	local self = setmetatable({} :: fields, MT)

	self._trove = ModuleUtils.Trove.new()
	self._scaleTrove = self._trove:Construct(ModuleUtils.Trove)
	self._stroke = stroke
	self._usingScale = false

	self._trove:Add(stroke.Destroying:Once(function()
		self:Destroy()
	end))

	return self
end

function GuiStrokeClass:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object).__index == MT
end

--[[
	Converts the UIStroke to scale with its parent element.
	If stroke on text, the scale will be based on the text size.
	If stroke on any other Gui object, the scale will be based on an average of the X & Y, or on one axis if <strong>primaryAxis</strong> is provided.
	<strong>sizeConstraint</strong>: Optional size constraint to limit the stroke size in pixels.
]]
function MT.UseScale(
	self: WrappedUiStroke,
	scale: number,
	primaryAxis: ("X" | "Y")?,
	sizeConstraint: NumberRange?
): WrappedUiStroke
	self._scaleTrove:Clean()
	local obj = self._stroke.Parent :: GuiObject
	if not obj then
		warn("UIStroke does not have a parent.")
		return self
	end
	self._usingScale = true

	local function getScale()
		local valueForScale
		if
			self:GetStroke().ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual
			and (obj:IsA("TextBox") or obj:IsA("TextLabel") or obj:IsA("TextButton"))
		then
			valueForScale = if not obj.TextFits
				then (obj.AbsoluteSize.X + obj.AbsoluteSize.Y) / 2
				else (obj.TextBounds.Y + obj.TextBounds.X) / 2
		elseif primaryAxis == "X" then
			valueForScale = obj.AbsoluteSize.X
		elseif primaryAxis == "Y" then
			valueForScale = obj.AbsoluteSize.Y
		else
			valueForScale = (obj.AbsoluteSize.X + obj.AbsoluteSize.Y) / 2
		end
		return valueForScale * scale
	end

	local function evaluateStrokeThickness()
		local thickness = getScale()
		self:GetStroke().Thickness = if sizeConstraint
			then math.clamp(thickness, sizeConstraint.Min, sizeConstraint.Max)
			else thickness
	end

	self._scaleTrove:Connect(obj:GetPropertyChangedSignal("AbsoluteSize"), evaluateStrokeThickness)
	self._scaleTrove:Connect(self._stroke:GetPropertyChangedSignal("ApplyStrokeMode"), evaluateStrokeThickness)
	self._scaleTrove:Connect(self._stroke:GetPropertyChangedSignal("Parent"), function()
		if not self._stroke.Parent then
			return
		end
		self:UseScale(scale, primaryAxis, sizeConstraint)
	end)
	evaluateStrokeThickness()
	return self
end

function MT.UseOffset(self: WrappedUiStroke, offset: number): WrappedUiStroke
	self._scaleTrove:Clean()
	self:GetStroke().Thickness = offset
	self._usingScale = false
	return self
end

function MT.GetStroke(self: WrappedUiStroke): UIStroke
	return self._stroke
end

function MT.UsingScale(self: WrappedUiStroke): boolean
	return self._usingScale
end

function MT.Destroy(self: WrappedUiStroke)
	self._trove:Clean()
end

-----------------------------
-- MAIN --
-----------------------------
return GuiStrokeClass
