--!strict
--@author: crusherfire
--@date: 10/7/24
--[[@description:
	Wrapper class that applies generic effects across all UI objects
]]
-----------------------------
-- SERVICES --
-----------------------------
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local ModuleUtils = require("../ModuleUtils")
local FunctionUtils = require("../FunctionUtils")
local Trove = ModuleUtils.Trove
local Input = require(script.Parent._Input)

-----------------------------
-- TYPES --
-----------------------------
-- This is for all of the properties of an object made from this class for type annotation purposes.
type self = {
	_trove: ModuleUtils.TroveType,
	_toolTipTrove: ModuleUtils.TroveType, -- Cleaned when tool tip is disabled.
	_notifTrove: ModuleUtils.TroveType, -- Cleaned when notifications are cleared.
	_object: GuiObject,
	_currentNotices: number,

	_shimmerEnabled: boolean?,
	_shimmerTrove: ModuleUtils.TroveType,
	_shimmer: GuiObject?,
}
export type ToolTipStyles = "INFO" | "WARNING"

export type ToolTipParams = {
	CustomToolTip: { -- for your own custom toolt tip (if provided, all other params are ignored except MouseOffset)
		ToolTip: GuiObject, -- template to clone from
		OnCreate: (tooltip: GuiObject) -> (), -- to customzie the custom tooltip
		OnEnterHover: (tooltip: GuiObject) -> (),
		OnExitHover: (tooltip: GuiObject) -> (), -- this function can yield to prevent immediate destruction of tooltip (if tooltip gets disabled)
	}?,
	MouseOffset: Vector2?, -- how the tooltip should be offset from the mouse or element (if locked) in pixels
	LockedToElement: boolean?, -- tool tip appears over element and doesn't follow mouse
	AnchorPoint: Vector2?,
	DescriptionText: string?,
	TitleText: string?,
	-- If both are provided, Style is applied first and then CustomizeTooltip is called.
	CustomizeTooltip: ((frame: ExampleToolTip) -> ())?, -- for your own custom tool tip styles for the default tooltip
	Style: ToolTipStyles?, -- built-in tool tip styles
}

type NotificationCorner = "UpperLeft" | "UpperRight" | "BottomLeft" | "BottomRight"

export type NotificationOptions = {
	Corner: NotificationCorner?,
	Color: Color3?,
	ClearSignal: ModuleUtils.GenericSignal?, -- For clearing this specific notice.
}

export type ShimmerParams = {
	Color: ColorSequence?,
	Rotation: number?,
}

-----------------------------
-- VARIABLES --
-----------------------------
local GuiObjectClass = {}
local MT = {}
MT.__index = MT
export type WrappedGuiObject = typeof(setmetatable({} :: self, MT))

local mouse = Input.Mouse.new()
local toolTipGui = script.ToolTipGui
local exampleToolTip = toolTipGui.ExampleToolTip
local exampleNotification = script.ExampleNotification
export type ExampleNotif = typeof(exampleNotification)
export type ExampleToolTip = typeof(exampleToolTip)

local objectCache = {}

-- CONSTANTS --
local PLAYER = Players.LocalPlayer

local TOP_NO_SIZE = UDim2.fromScale(0, 0.3)
local BOTTOM_NO_SIZE = UDim2.fromScale(1, 0)
local TOP_SIZE = exampleToolTip.TopFrame.Size
local BOTTOM_SIZE = exampleToolTip.BottomFrame.Size
local TEXT_TWEEN_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
local SIZE_TWEEN_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Cubic, Enum.EasingDirection.InOut)
local ANCHOR_POINT_IDENTITY = Vector2.zero
local CAMERA = workspace.CurrentCamera

local CORNER_TO_UDIM2 = {
	UpperLeft = UDim2.fromScale(0, 0),
	UpperRight = UDim2.fromScale(1, 0),
	BottomLeft = UDim2.fromScale(0, 1),
	BottomRight = UDim2.fromScale(1, 1),
}
local CORNER_TO_ANCHOR_POINT = {
	UpperLeft = Vector2.new(0.2, 0.2),
	UpperRight = Vector2.new(0.8, 0.2),
	BottomLeft = Vector2.new(0.2, 0.8),
	BottomRight = Vector2.new(0.8, 0.8),
}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local customizeTooltip = {
	INFO = function(frame: ExampleToolTip)
		local color = Color3.fromRGB(87, 120, 140)
		local h, s, v = color:ToHSV()
		local darkerColor = Color3.fromHSV(h, s, v * 0.7)
		frame.TopFrame.Icon.Image = "rbxassetid://13868179798"
		frame.TopFrame.BackgroundColor3 = color
		frame.BottomFrame.BackgroundColor3 = darkerColor
	end,
	WARNING = function(frame: ExampleToolTip)
		local color = Color3.fromRGB(144, 81, 26)
		local h, s, v = color:ToHSV()
		local darkerColor = Color3.fromHSV(h, s, v * 0.7)
		frame.TopFrame.Icon.Image = "rbxassetid://14939539960"
		frame.TopFrame.BackgroundColor3 = color
		frame.BottomFrame.BackgroundColor3 = darkerColor
	end,
} :: { [ToolTipStyles]: (frame: ExampleToolTip) -> () }

local function createToolTip(params: ToolTipParams): ExampleToolTip
	local clone = exampleToolTip:Clone()
	clone.TopFrame.TitleLabel.Text = params.TitleText or ""
	clone.BottomFrame.DescriptionLabel.Text = params.DescriptionText or ""
	clone.Visible = false

	clone.TopFrame.Size = TOP_NO_SIZE
	clone.BottomFrame.Size = BOTTOM_NO_SIZE
	clone.TopFrame.TitleLabel.TextTransparency = 1
	clone.BottomFrame.DescriptionLabel.TextTransparency = 1
	clone.TopFrame.UICorner.CornerRadius = if not params.DescriptionText
		then clone.UICorner.CornerRadius
		else UDim.new()

	clone.AnchorPoint = params.AnchorPoint or ANCHOR_POINT_IDENTITY

	if params.Style then
		customizeTooltip[params.Style](clone)
	end
	if params.CustomizeTooltip then
		local success, err = pcall(function()
			params.CustomizeTooltip(clone)
		end)
		if not success then
			warn(err)
		end
	end

	clone.Parent = toolTipGui
	return clone
end

local function createShimmerEffect(self: WrappedGuiObject, params: ShimmerParams?): (GuiObject, UIGradient)
	local shimmerEffect: GuiObject = if self:GetObject():IsA("ImageButton")
		then Instance.new("ImageLabel")
		else Instance.new("Frame")
	if shimmerEffect:IsA("ImageLabel") then
		local button = self:GetObject() :: ImageButton
		shimmerEffect.Image = button.Image
		shimmerEffect.ImageColor3 = Color3.new(1, 1, 1)
		shimmerEffect.ScaleType = button.ScaleType
		shimmerEffect.SliceCenter = button.SliceCenter
	else
		local uiCorner = self:GetObject():FindFirstChildWhichIsA("UICorner")
		if uiCorner then
			local uiCornerClone = uiCorner:Clone()
			uiCornerClone.Parent = shimmerEffect
		end
	end

	FunctionUtils.Interface.center(shimmerEffect)
	shimmerEffect.Size = UDim2.fromScale(1, 1)
	shimmerEffect.BackgroundTransparency = 0
	shimmerEffect.ZIndex = 1000

	local uiGradient = Instance.new("UIGradient")
	local whiteColorSequence = ColorSequence.new(Color3.new(1, 1, 1))
	uiGradient.Color = if params and params.Color then params.Color else whiteColorSequence
	uiGradient.Rotation = if params and params.Rotation then params.Rotation else 0
	uiGradient.Parent = shimmerEffect
	uiGradient.Offset = Vector2.new(-1, 0)
	uiGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.5, 0.4),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 1),
	})

	shimmerEffect.Parent = self:GetObject()

	return shimmerEffect, uiGradient
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates a new WrappedGuiObject
function GuiObjectClass.new(guiObject: GuiObject): WrappedGuiObject
	local obj = GuiObjectClass:GetObjectByObject(guiObject)
	if obj then
		return obj
	end

	local self = setmetatable({} :: self, MT)

	self._trove = Trove.new()
	self._shimmerTrove = self._trove:Construct(Trove)
	self._toolTipTrove = self._trove:Construct(Trove)
	self._notifTrove = self._trove:Construct(Trove)
	self._object = guiObject
	self._currentNotices = 0

	self._trove:Add(guiObject.Destroying:Once(function()
		self:Destroy()
	end))

	table.insert(objectCache, self)
	return self
end

function GuiObjectClass:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object).__index == MT
end

function GuiObjectClass:GetObjectByObject(object: GuiObject): WrappedGuiObject?
	for _, classObj in ipairs(objectCache) do
		if classObj:GetObject() == object then
			return classObj
		end
	end
	return nil
end

-- Adds a notification icon/number to the corner of the GuiObject.
function MT.Notify(self: WrappedGuiObject, notifyOptions: NotificationOptions?): WrappedGuiObject
	self._currentNotices += 1
	local frame = self:GetObject():FindFirstChild("_activeNotification") :: ExampleNotif

	local position = if notifyOptions and notifyOptions.Corner
		then CORNER_TO_UDIM2[notifyOptions.Corner]
		else CORNER_TO_UDIM2.UpperRight
	local anchorPoint = if notifyOptions and notifyOptions.Corner
		then CORNER_TO_ANCHOR_POINT[notifyOptions.Corner]
		else CORNER_TO_ANCHOR_POINT.UpperRight

	if not frame then
		frame = exampleNotification:Clone()
		self._notifTrove:Add(frame)
	end
	frame.Position = position
	frame.AnchorPoint = anchorPoint
	frame.Icon.Visible = if self._currentNotices <= 1 then true else false
	frame.CountLabel.Visible = not frame.Icon.Visible
	frame.CountLabel.Text = self:GetNotices()
	frame.Visible = true
	frame.Parent = self:GetObject()

	if notifyOptions and notifyOptions.ClearSignal then
		self._notifTrove:Add(notifyOptions.ClearSignal:Once(function()
			self._currentNotices -= 1
			frame.Icon.Visible = if self._currentNotices <= 1 then true else false
			frame.CountLabel.Visible = not frame.Icon.Visible
			frame.CountLabel.Text = self:GetNotices()
			if self._currentNotices <= 0 then
				self:ClearNotices()
			end
		end))
	end

	return self
end

function MT.ToggleShimmer(self: WrappedGuiObject, enable: boolean?, params: ShimmerParams?): WrappedGuiObject
	if enable and self:IsShimmerEnabled() then
		return self
	elseif not enable and not self:IsShimmerEnabled() then
		return self
	end

	self._shimmerEnabled = if enable ~= nil then enable else false

	if self:IsShimmerEnabled() then
		local shimmer, gradient = createShimmerEffect(self, params)
		self._shimmerTrove:Add(shimmer)
		local tween = TweenService:Create(
			gradient,
			TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, -1, false, 1),
			{ Offset = Vector2.new(1, 0) }
		)
		tween:Play()
		self._shimmerTrove:Add(tween)
		self._shimmer = shimmer
	else
		self._shimmerTrove:Clean()
		self._shimmer = nil
	end

	return self
end

function MT.IsShimmerEnabled(self: WrappedGuiObject)
	return self._shimmerEnabled
end

-- Clears ALL notices.
function MT.ClearNotices(self: WrappedGuiObject): WrappedGuiObject
	self._notifTrove:Clean()
	self._currentNotices = 0
	return self
end

function MT.GetNotices(self: WrappedGuiObject): number
	return self._currentNotices
end

function MT.GetObject(self: WrappedGuiObject): GuiObject
	return self._object
end

-- Displays a tool tip when hovering over the GuiObject.
function MT.ToggleToolTip(self: WrappedGuiObject, enable: boolean?, params: ToolTipParams?): WrappedGuiObject
	if enable and not params then
		warn("Expected tool tip params when enabling tool tip!")
		return self
	end

	if enable and toolTipGui.Parent ~= PLAYER.PlayerGui then
		toolTipGui.Parent = PLAYER.PlayerGui
	end

	if not enable then
		self._toolTipTrove:Clean()
		return self
	end
	local params = params :: ToolTipParams

	-- Enabling tool tip
	if params.CustomToolTip then
		local toolTip = params.CustomToolTip.ToolTip:Clone()
		if params.CustomToolTip.OnCreate then
			params.CustomToolTip.OnCreate(toolTip)
		end
		toolTip.Visible = false
		toolTip.Parent = toolTipGui
		local offset: Vector2
		do
			if params.MouseOffset then
				offset = params.MouseOffset
			elseif toolTip.AnchorPoint.X == 1 then
				offset = Vector2.new(-5, -5)
			elseif toolTip.AnchorPoint.X == 0 then
				offset = Vector2.new(15, -5)
			elseif toolTip.AnchorPoint.X == 0.5 then
				offset = Vector2.new(0, 5)
			end
		end
		self._toolTipTrove:Add(function()
			if toolTip.Visible then
				params.CustomToolTip.OnExitHover(toolTip)
			end
			toolTip:Destroy()
		end)
		self._toolTipTrove:Connect(self._object.MouseEnter, function()
			params.CustomToolTip.OnEnterHover(toolTip)
		end)
		self._toolTipTrove:Connect(self._object.MouseLeave, function()
			params.CustomToolTip.OnExitHover(toolTip)
		end)
		local function onVisiblityChanged()
			local visible = FunctionUtils.Interface.trulyVisible(self._object)
			if not visible then
				params.CustomToolTip.OnExitHover(toolTip)
			end
		end
		for _, ancestor in ipairs(FunctionUtils.Object.getAncestors(self._object)) do
			if ancestor:IsA("LayerCollector") then
				self._toolTipTrove:Connect(ancestor:GetPropertyChangedSignal("Enabled"), onVisiblityChanged)
			elseif ancestor:IsA("GuiObject") then
				self._toolTipTrove:Connect(ancestor:GetPropertyChangedSignal("Visible"), onVisiblityChanged)
			end
		end
		self._toolTipTrove:Connect(self._object:GetPropertyChangedSignal("Visible"), onVisiblityChanged)
		if params.LockedToElement then
			local function evaluateToolTipPosition()
				local absolutePos = self._object.AbsolutePosition
				local absoluteSize = self._object.AbsoluteSize
				local isTopHalf = absolutePos.Y < (CAMERA.ViewportSize / 2).Y

				local newPosition
				if isTopHalf then
					toolTip.AnchorPoint = Vector2.new(0.5, 0)
					newPosition = absolutePos + Vector2.new(absoluteSize.X / 2, absoluteSize.Y)
				else
					toolTip.AnchorPoint = Vector2.new(0.5, 1)
					newPosition = absolutePos + Vector2.new(absoluteSize.X / 2, 0)
				end
				newPosition += if isTopHalf then offset else -offset
				toolTip.Position = UDim2.fromOffset(newPosition.X, newPosition.Y)
			end

			self._toolTipTrove:Connect(
				self._object:GetPropertyChangedSignal("AbsolutePosition"),
				evaluateToolTipPosition
			)
			self._toolTipTrove:Connect(self._object:GetPropertyChangedSignal("AbsoluteSize"), evaluateToolTipPosition)
			evaluateToolTipPosition()
		else
			self._toolTipTrove:Connect(mouse.Moved, function(position: Vector2)
				if not toolTip.Visible then
					return
				end
				toolTip.Position = UDim2.fromOffset(position.X + offset.X, position.Y + offset.Y)
			end)
		end
	else
		local toolTip = createToolTip(params :: ToolTipParams)
		local offset: Vector2 = if params.MouseOffset
			then params.MouseOffset
			elseif toolTip.AnchorPoint.X == 1 then Vector2.new(-5, -5)
			else Vector2.new(15, -5)
		local tweenTrove = Trove.new()

		local function displayToolTip(frame: ExampleToolTip)
			tweenTrove:Clean()

			tweenTrove:Add(task.spawn(function()
				frame.Visible = true
				local tween
				if toolTip.TopFrame.Size ~= TOP_SIZE then
					tween = TweenService:Create(toolTip.TopFrame, SIZE_TWEEN_INFO, { Size = TOP_SIZE })
					tween:Play()
					tween.Completed:Wait()
				end
				TweenService:Create(toolTip.TopFrame.TitleLabel, TEXT_TWEEN_INFO, { TextTransparency = 0 }):Play()
				if toolTip.BottomFrame.DescriptionLabel.Text ~= "" then
					if toolTip.BottomFrame.Size ~= BOTTOM_SIZE then
						tween = TweenService:Create(toolTip.BottomFrame, SIZE_TWEEN_INFO, { Size = BOTTOM_SIZE })
						tween:Play()
						tween.Completed:Wait()
					end
					TweenService:Create(toolTip.BottomFrame.DescriptionLabel, TEXT_TWEEN_INFO, { TextTransparency = 0 })
						:Play()
				end
			end))
		end

		local function hideToolTip(frame: ExampleToolTip)
			tweenTrove:Clean()

			tweenTrove:Add(task.spawn(function()
				local tween
				if toolTip.BottomFrame.Size.Y.Scale > 0 then
					tween = TweenService:Create(toolTip.BottomFrame, SIZE_TWEEN_INFO, { Size = BOTTOM_NO_SIZE })
					tween:Play()
					TweenService:Create(toolTip.BottomFrame.DescriptionLabel, TEXT_TWEEN_INFO, { TextTransparency = 1 })
						:Play()
					tween.Completed:Wait()
				end
				tween = TweenService:Create(toolTip.TopFrame, SIZE_TWEEN_INFO, { Size = TOP_NO_SIZE })
				TweenService:Create(toolTip.TopFrame.TitleLabel, TEXT_TWEEN_INFO, { TextTransparency = 1 }):Play()
				tween:Play()
				tween.Completed:Wait()
				frame.Visible = false
			end))
		end

		self._toolTipTrove:Add(function()
			if toolTip.Visible then
				hideToolTip(toolTip)
				toolTip:GetPropertyChangedSignal("Visible"):Wait()
			end
			tweenTrove:Clean()
			toolTip:Destroy()
		end)
		self._toolTipTrove:Connect(self._object.MouseEnter, function()
			displayToolTip(toolTip)
		end)
		self._toolTipTrove:Connect(self._object.MouseLeave, function()
			hideToolTip(toolTip)
		end)
		if params.LockedToElement then
			local function evaluateToolTipPosition()
				local absolutePos = self._object.AbsolutePosition
				local absoluteSize = self._object.AbsoluteSize
				local isTopHalf = absolutePos.Y >= (CAMERA.ViewportSize / 2).Y

				local newPosition
				if isTopHalf then
					toolTip.AnchorPoint = Vector2.new(0.5, 0)
					newPosition = absolutePos + Vector2.new(absoluteSize.X / 2, absoluteSize.Y)
				else
					toolTip.AnchorPoint = Vector2.new(0.5, 1)
					newPosition = absolutePos + Vector2.new(absoluteSize.X / 2, 0)
				end
				toolTip.Position = UDim2.fromOffset(newPosition.X, newPosition.Y)
			end
			self._toolTipTrove:Connect(
				self._object:GetPropertyChangedSignal("AbsolutePosition"),
				evaluateToolTipPosition
			)
			self._toolTipTrove:Connect(self._object:GetPropertyChangedSignal("AbsoluteSize"), evaluateToolTipPosition)
		else
			self._toolTipTrove:Connect(mouse.Moved, function(position: Vector2)
				if not toolTip.Visible then
					return
				end
				toolTip.Position = UDim2.fromOffset(position.X + offset.X, position.Y + offset.Y)
			end)
		end
	end

	return self
end

function MT.Destroy(self: WrappedGuiObject)
	self._trove:Clean()
	local i = table.find(objectCache, self)
	if i then
		table.remove(objectCache, i)
	end
end

-----------------------------
-- MAIN --
-----------------------------
return GuiObjectClass
