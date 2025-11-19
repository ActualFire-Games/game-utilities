--!strict
--@author: C0DERACTU4L @CoderActual & crusherfire
--@date: 8/8/2024
--[[@description:
	
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local ModuleUtils = require("../ModuleUtils")
local Trove = ModuleUtils.Trove
local FunctionUtils = require("../FunctionUtils")

-----------------------------
-- TYPES --
-----------------------------
-- This is for all of the properties of an object made from this class for type annotation purposes.
type self = {
	_trove: ModuleUtils.TroveType,
	_label: TextLabel,
	_dropShadow: ExampleDropShadow?,
}

export type ExampleDropShadow = typeof(script.ExampleDropShadow)

-----------------------------
-- VARIABLES --
-----------------------------
local GuiTextClass = {}

local MT = {}
MT.__index = MT
export type WrappedTextLabel = typeof(setmetatable({} :: self, MT))

-- CONSTANTS --
local COPY_PROPERTIES = {
	"FontFace",
	"LineHeight",
	"MaxVisibleGraphemes",
	"RichText",
	"Text",
	"TextDirection",
	"TextScaled",
	"TextSize",
	"TextTruncate",
	"TextWrapped",
	"TextXAlignment",
	"TextYAlignment",
}
local IGNORE_CONSTRAINTS = {
	UIStroke = true,
}
local UDIM2_SCALE_ONE = UDim2.fromScale(1, 1)
local UDIM2_IDENTITY = UDim2.fromScale(0, 0)

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function createDropShadow(self: WrappedTextLabel): ExampleDropShadow
	local label = self:GetLabel()
	do
		-- Destroy placeholders
		local other = label:FindFirstChild("_DropShadow")
		if other then
			other:Destroy()
		end
	end
	local origParent = label.Parent
	local frame = script.ExampleDropShadow:Clone()
	frame.Name = "_DropShadow"
	frame.Size = label.Size
	frame.Position = label.Position
	frame.AnchorPoint = label.AnchorPoint
	frame.LayoutOrder = label.LayoutOrder
	frame.ZIndex = label.ZIndex
	frame.BackgroundTransparency = 1

	label.Parent = frame
	label.Size = UDIM2_SCALE_ONE
	label.Position = UDIM2_IDENTITY
	label.AnchorPoint = Vector2.zero

	local shadowLabel = frame._ShadowLabel
	for _, property in ipairs(COPY_PROPERTIES) do
		(shadowLabel :: any)[property] = (label :: any)[property]
	end
	shadowLabel.BackgroundTransparency = 1
	shadowLabel.AnchorPoint = Vector2.zero
	shadowLabel.Position = UDIM2_IDENTITY
	shadowLabel.Size = UDIM2_SCALE_ONE
	shadowLabel.ZIndex = label.ZIndex - 1
	shadowLabel.Parent = frame

	frame.Parent = origParent

	return frame
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates a new WrappedTextLabel.
function GuiTextClass.new(textObject: TextLabel): WrappedTextLabel
	assert(textObject:IsA("TextLabel"), "GuiTextClass: Inputted param must be a TextLabel.")
	local self = setmetatable({} :: self, MT)

	self._trove = Trove.new()
	self._label = textObject

	self._trove:Add(textObject.Destroying:Once(function()
		self:Destroy()
	end))

	return self
end

function GuiTextClass:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object).__index == MT
end

-- Creates a drop shadow on the text label.
-- <strong>WARNING!</strong> This will change the parent hierarchy for the text label.
-- <strong>color</strong>: Optional color override for the dropshadow (default is black)
-- <strong>offset</strong>: Optional offset override (default offset is (2, 2))
-- <strong>transparency</strong>: Optional transparency override (default is 0.4)
function MT.CreateDropShadow(
	self: WrappedTextLabel,
	color: Color3?,
	offset: Vector2?,
	transparency: number?
): WrappedTextLabel
	local label = self._label :: TextLabel
	local dropShadow = createDropShadow(self)
	self._dropShadow = dropShadow
	local shadowLabel = dropShadow._ShadowLabel

	local offset = offset or Vector2.new(2, 2)
	shadowLabel.Position = UDIM2_IDENTITY + UDim2.fromOffset(offset.X, offset.Y)
	shadowLabel.TextTransparency = transparency or 0.4

	for _, property in ipairs(COPY_PROPERTIES) do
		self._trove:Connect(label:GetPropertyChangedSignal(property), function()
			if property == "Text" then
				-- Removes custom text color, strokes, and highlights (since a dropshadow doesn't need those)
				local newText = label.Text
					:gsub("(<font[^>]*>)", function(tag)
						-- Remove the font color attribute, whether it's hex, rgb(), etc.
						return tag:gsub("%s*color%s*=%s*[\"'][^\"']*[\"']", "")
					end)
					:gsub("</?stroke%s*[^>]*>", "")
					:gsub("</?mark%s*[^>]*>", "")

				shadowLabel.Text = newText
			else
				pcall(function()
					shadowLabel[property] = (label :: any)[property]
				end)
			end
		end)
	end

	-- UI constraint copying/listening
	do
		local function onNewConstraint(constraint: UIBase)
			local clone = constraint:Clone()
			clone.Parent = shadowLabel
			self._trove:Add(constraint.Destroying:Once(function()
				clone:Destroy()
			end))
			self._trove:Connect(constraint.Changed, function(property)
				(clone :: any)[property] = (constraint :: any)[property]
			end)
		end

		for _, item in ipairs(label:GetChildren()) do
			if not item:IsA("UIBase") then
				continue
			end
			if IGNORE_CONSTRAINTS[item.ClassName] then
				continue
			end
			onNewConstraint(item)
		end

		self._trove:Connect(label.ChildAdded, function(child)
			if not child:IsA("UIBase") then
				return
			end
			if IGNORE_CONSTRAINTS[child.ClassName] then
				return
			end
			onNewConstraint(child)
		end)
	end

	return self
end

-- Returns the drop shadow frame (if present).
-- It's' not recommended to attempt to modify anything on the drop shadow. Use it for read-only values.
function MT.GetDropShadow(self: WrappedTextLabel): ExampleDropShadow?
	return self._dropShadow
end

function MT.GetLabel(self: WrappedTextLabel): TextLabel
	return self._label
end

function MT.Destroy(self: WrappedTextLabel)
	self._trove:Clean()
	setmetatable(self :: any, nil)
	table.clear(self :: any)
end

-----------------------------
-- MAIN --
-----------------------------
return GuiTextClass
