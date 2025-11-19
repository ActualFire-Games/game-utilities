--!strict
--@author: crusherfire & CoderActual
--@date: 8/9/24
--[[@description:
	Wrapper class for GuiButtons. Chainable functions for GuiButtons!
]]
-----------------------------
-- SERVICES --
-----------------------------
local TweenService = game:GetService("TweenService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local ModuleUtils = require("../ModuleUtils")
local FunctionUtils = require("../FunctionUtils")
local Signal = ModuleUtils.Signal
local Trove = ModuleUtils.Trove
local Input = require(script.Parent._Input)

-----------------------------
-- TYPES --
-----------------------------
export type ButtonTweenInfo = {
	BackgroundColor3: TweenInfo?,
	Size: TweenInfo?,
	Position: TweenInfo?,
	Rotation: TweenInfo?,
}
type TweenableProperties = {
	BackgroundColor3: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	Rotation: number?,
}
export type ButtonTheme = {
	Properties: {
		Enter: TweenableProperties,
		Exit: TweenableProperties,
	},

	EnterTweenInfo: ButtonTweenInfo,
	ExitTweenInfo: ButtonTweenInfo,
}
export type ButtonThemeModification = {
	Properties: {
		Enter: TweenableProperties?,
		Exit: TweenableProperties?,
	}?,

	EnterTweenInfo: ButtonTweenInfo?,
	ExitTweenInfo: ButtonTweenInfo?,
}

-- This is for all of the properties of an object made from this class for type annotation purposes.

type self = {
	-- Private members
	_trove: ModuleUtils.TroveType,
	_shadowTrove: ModuleUtils.TroveType, -- cleaned each hover
	_shadowLifetimeTrove: ModuleUtils.TroveType, -- cleaned when dropshadow is removed
	_button: GuiButton,
	_originalPosition: UDim2, -- capture the button's original position
	_buttonProperties: ButtonProperties,
	_shadowProperties: ShadowProperties,
	_activeTweens: {
		Enter: { [string]: Tween },
		Exit: { [string]: Tween },
	},
	_deselectGroup: string,
	_shimmerTrove: ModuleUtils.TroveType, -- cleaned when shimmer is removed
	_shimmer: GuiObject?,
	_shadow: GuiObject?,

	-- Conditions
	_debounce: boolean,
	_isLocked: boolean, -- Stops any user input.
	_isSelected: boolean,
	_shimmerEnabled: boolean,
	_shadowEnabled: boolean,
	_isHovering: boolean,
	_doClickSound: boolean,
	_doHoverSound: boolean,
	_hasActiveInput: boolean, -- boolean is true if input begins on button and has not ended yet

	-- Public members
	Signals: {
		Selected: ModuleUtils.SignalType<
			(user: "Player" | "Script", inputObj: InputObject?) -> (),
			("Player" | "Script", InputObject?)
		>,
		Deselected: ModuleUtils.SignalType<
			(user: "Player" | "Script", inputObj: InputObject?) -> (),
			("Player" | "Script", InputObject?)
		>,
		Activated: ModuleUtils.SignalType<
			(user: "Player" | "Script", inputObj: InputObject?, clickCount: number) -> (),
			("Player" | "Script", InputObject?, number)
		>,
		InputBegan: ModuleUtils.SignalType<(input: InputObject) -> (), (InputObject)>,
		InputEnded: ModuleUtils.SignalType<(input: InputObject) -> (), (InputObject)>,
		InputChanged: ModuleUtils.SignalType<(input: InputObject) -> (), (InputObject)>,
		MouseEnter: ModuleUtils.SignalType<(x: number, y: number) -> (), (number, number)>,
		MouseLeave: ModuleUtils.SignalType<(x: number, y: number) -> (), (number, number)>,
	},
}
type Signals = "Selected" | "Deselected" | "Activated" | "MouseEnter" | "MouseLeave"

type ButtonProperties = {
	HoverTheme: ButtonTheme,
	SelectionTheme: ButtonTheme,
	AutoDeselect: boolean,
	OneClick: boolean,

	ClickSound: Sound,
	HoverSound: Sound,
}
export type ButtonParams = {
	AutoDeselect: boolean?,
	OneClick: boolean?,

	ClickSound: Sound?,
	HoverSound: Sound?,

	--HoverColor: Color3?,
	--HoverBorderColor: Color3?,
	--HoverBorderLineJoinMode: Enum.LineJoinMode?,
	----HoverInfoPanel: MouseHoverPanelProperties?,
	--HoverBorderThickness: number?,
}

type ShadowProperties = {
	XOffset: number,
	YOffset: number,
}

export type ShadowParams = {
	BackgroundColor3: Color3?,
	XOffset: number,
	YOffset: number,
	BackgroundTransparency: number?,
	Parent: Instance?,
}

export type ShimmerParams = {
	Color: ColorSequence?,
	Rotation: number?,
}
-----------------------------
-- VARIABLES --
-----------------------------
local GuiButtonClass = {}
local MT = {}
MT.__index = MT
export type WrappedGuiButton = typeof(setmetatable({} :: self, MT))

local logger = ModuleUtils.Logger.new(script.Name)
local buttonCache = {} :: { WrappedGuiButton }
local deselectGroups = {
	DEFAULT = {},
}
local touch = Input.Touch.new()

-- CONSTANTS --
local DEFAULT_SOUNDS = {
	HOVER = FunctionUtils.Game.createSound({ SoundId = "rbxassetid://9126031928", Volume = 1 }),
	CLICK = FunctionUtils.Game.createSound({ SoundId = "rbxassetid://9125418953", Volume = 2 }),
}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
local applyInputEnterTheme, applyMouseLeaveTheme, applySelectedTheme, applyDeselectedTheme

function applyInputEnterTheme(self: WrappedGuiButton)
	local hoverTheme = self._buttonProperties.HoverTheme
	local selectionTheme = self._buttonProperties.SelectionTheme
	local enterTweenInfo = hoverTheme.EnterTweenInfo

	do
		-- cancel any tweens!
		local names = { "HoverColor", "HoverSize", "HoverPosition", "HoverRotation" }

		for _, name in ipairs(names) do
			if self._activeTweens.Exit[name] then
				self._activeTweens.Exit[name]:Cancel()
				self._activeTweens.Exit[name] = nil
			end
		end
	end

	for name, value in pairs(hoverTheme.Properties.Enter) do
		if self:IsSelected() and selectionTheme.Properties.Enter[name] then
			-- Selection theme takes priority for this property!
			warn(`Property: {name} is overriden by selection theme.`)
			continue
		elseif not self:IsSelected() and selectionTheme.Properties.Exit[name] then
			-- Selection theme takes priority for this property!
			warn(`Property: {name} is overriden by selection theme.`)
			continue
		end

		if enterTweenInfo[name] then
			local goal = {}
			if name == "BackgroundColor3" then
				goal[name] = value
			else
				-- add original value + new offset
				goal[name] = hoverTheme.Properties.Exit[name] + value
			end

			local tween = TweenService:Create(self._button, enterTweenInfo[name], goal)
			self._activeTweens.Enter[`Hover{name}`] = tween
			tween:Play()
		else
			local button = self._button :: any -- resolves a type annotation issue
			if name == "BackgroundColor3" then
				button[name] = value
			else
				-- add original value + new offset
				button[name] = hoverTheme.Properties.Exit[name] + value
			end
		end
	end
end

function applyMouseLeaveTheme(self: WrappedGuiButton)
	local hoverTheme = self._buttonProperties.HoverTheme
	local selectionTheme = self._buttonProperties.SelectionTheme
	local exitTweenInfo = hoverTheme.ExitTweenInfo

	do
		-- cancel any tweens!
		local names = { "HoverColor", "HoverSize", "HoverPosition", "HoverRotation" }

		for _, name in ipairs(names) do
			if self._activeTweens.Enter[name] then
				self._activeTweens.Enter[name]:Cancel()
				self._activeTweens.Enter[name] = nil
			end
		end
	end

	for name, value in pairs(hoverTheme.Properties.Exit) do
		if self:IsSelected() and selectionTheme.Properties.Enter[name] then
			-- Selection theme takes priority for this property!
			warn(`Property: {name} is overriden by selection theme.`)
			continue
		elseif not self:IsSelected() and selectionTheme.Properties.Exit[name] then
			-- Selection theme takes priority for this property!
			warn(`Property: {name} is overriden by selection theme.`)
			continue
		end

		if exitTweenInfo[name] then
			local goal = {}
			if name == "BackgroundColor3" then
				goal[name] = value
			else
				goal[name] = value
			end

			local tween = TweenService:Create(self._button, exitTweenInfo[name], goal)
			self._activeTweens.Enter[`Hover{name}`] = tween
			tween:Play()
		else
			local button = self._button :: any -- resolves a type annotation issue
			if name == "BackgroundColor3" then
				button[name] = value
			else
				button[name] = value
			end
		end
	end
end

function applySelectedTheme(self: WrappedGuiButton)
	local selectionTheme = self._buttonProperties.SelectionTheme
	local enterTweenInfo = selectionTheme.EnterTweenInfo

	do
		-- cancel any tweens!
		local names = { "SelectionColor", "SelectionSize", "SelectionPosition", "SelectionRotation" }

		for _, name in ipairs(names) do
			if self._activeTweens.Exit[name] then
				self._activeTweens.Exit[name]:Cancel()
				self._activeTweens.Exit[name] = nil
			end
		end
	end

	for name, value in pairs(selectionTheme.Properties.Enter) do
		if enterTweenInfo[name] then
			local goal = {}
			if name == "BackgroundColor3" then
				goal[name] = value
			else
				-- add original value + new offset
				goal[name] = selectionTheme.Properties.Exit[name] + value
			end

			local tween = TweenService:Create(self._button, enterTweenInfo[name], goal)
			self._activeTweens.Enter[`Selection{name}`] = tween
			tween:Play()
		else
			local button = self._button :: any -- resolves a type annotation issue
			if name == "BackgroundColor3" then
				button[name] = value
			else
				-- add original value + new offset
				button[name] = selectionTheme.Properties.Exit[name] + value
			end
		end
	end
end

function applyDeselectedTheme(self: WrappedGuiButton)
	local selectionTheme = self._buttonProperties.SelectionTheme
	local exitTweenInfo = selectionTheme.ExitTweenInfo

	do
		-- cancel any tweens!
		local names = { "SelectionColor", "SelectionSize", "SelectionPosition", "SelectionRotation" }

		for _, name in ipairs(names) do
			if self._activeTweens.Enter[name] then
				self._activeTweens.Enter[name]:Cancel()
				self._activeTweens.Enter[name] = nil
			end
		end
	end

	for name, value in pairs(selectionTheme.Properties.Exit) do
		if exitTweenInfo[name] then
			local goal = {}
			if name == "BackgroundColor3" then
				goal[name] = value
			else
				goal[name] = value
			end

			local tween = TweenService:Create(self._button, exitTweenInfo[name], goal)
			self._activeTweens.Enter[`Hover{name}`] = tween
			tween:Play()
		else
			local button = self._button :: any -- resolves a type annotation issue
			if name == "BackgroundColor3" then
				button[name] = value
			else
				button[name] = value
			end
		end
	end
end

local function updateDeselectGroup(groupName: string)
	for _, button in ipairs(GuiButtonClass:GetDeselectGroupByName(groupName)) do
		if button:IsSelected() and button:IsAutoDeselect() then
			button:Deselect()
		end
	end
end

local function onButtonActivated(self: WrappedGuiButton, inputObj: InputObject?, clickCount: number)
	if self:OnDebounce() then
		return
	end
	if self:CanDoClickSound() then
		FunctionUtils.Game.playSoundClone(self._buttonProperties.ClickSound, game:GetService("SoundService"))
	end
	local userOverride: any = if inputObj then "Player" else "Script"

	if self:IsSelected() then
		self:Deselect(userOverride, inputObj)
	else
		self:Select(userOverride, inputObj)
		if self:IsOneClick() then
			self:Deselect(userOverride, inputObj)
		end
	end
	self.Signals.Activated:FireDefer("Player", inputObj, clickCount)
end

local function getDefaultTheme(): ButtonTheme
	local theme: ButtonTheme = {
		Properties = {
			Enter = {},
			Exit = {},
		},
		EnterTweenInfo = {},
		ExitTweenInfo = {},
	}
	return theme
end

local function getDefaultShadowParams(): ShadowParams
	return {
		BackgroundTransparency = 0.5,
		XOffset = 5,
		YOffset = 5,
		BackgroundColor3 = Color3.new(0, 0, 0),
	}
end

local function createShimmerEffect(self: WrappedGuiButton, params: ShimmerParams?): (GuiObject, UIGradient)
	local shimmerEffect: GuiObject = if self._button:IsA("ImageButton")
		then Instance.new("ImageLabel")
		else Instance.new("Frame")
	if shimmerEffect:IsA("ImageLabel") then
		local button = self._button :: ImageButton
		shimmerEffect.Image = button.Image
		shimmerEffect.ImageColor3 = Color3.new(1, 1, 1)
		shimmerEffect.ScaleType = button.ScaleType
		shimmerEffect.SliceCenter = button.SliceCenter
	else
		local uiCorner = self._button:FindFirstChildWhichIsA("UICorner")
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
	uiGradient.Rotation = if params and params.Rotation then params.Rotation else 25
	uiGradient.Parent = shimmerEffect
	uiGradient.Offset = Vector2.new(-1, 0)
	uiGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(0.7, 1),
		NumberSequenceKeypoint.new(1, 1),
	})

	shimmerEffect.Parent = self._button

	return shimmerEffect, uiGradient
end

local function createDropShadow(self: WrappedGuiButton, params: ShadowParams): GuiObject
	local screenGui = self._button:FindFirstAncestorWhichIsA("ScreenGui") :: ScreenGui
	if not screenGui then
		warn("Failed to get ScreenGui")
	end

	local dropShadow = Instance.new("Frame")
	local buttonPos = if screenGui.ZIndexBehavior == Enum.ZIndexBehavior.Sibling
		then UDim2.fromScale(0.5, 0.5)
		else self._button.Position
	dropShadow.Size = if screenGui.ZIndexBehavior == Enum.ZIndexBehavior.Sibling
		then UDim2.fromScale(1, 1)
		else self._button.Size
	dropShadow.AnchorPoint = self._button.AnchorPoint
	dropShadow.Position = UDim2.new(
		buttonPos.X.Scale,
		buttonPos.X.Offset + params.XOffset,
		buttonPos.Y.Scale,
		buttonPos.Y.Offset + params.YOffset
	)
	dropShadow.BackgroundColor3 = params.BackgroundColor3 or Color3.new(0, 0, 0)
	dropShadow.BackgroundTransparency = params.BackgroundTransparency or 0.5
	dropShadow.ZIndex = self._button.ZIndex - 1

	local uiCorner = self._button:FindFirstChildWhichIsA("UICorner")
	if uiCorner then
		local uiCornerClone = uiCorner:Clone()
		uiCornerClone.Parent = dropShadow
	end

	local uiAspectRatio = self._button:FindFirstChildWhichIsA("UIAspectRatioConstraint")
	if uiAspectRatio then
		local uiAspectRatioClone = uiAspectRatio:Clone()
		uiAspectRatioClone.Parent = dropShadow
	end

	dropShadow.Visible = self._button.Visible
	dropShadow.Parent = params.Parent or self._button.Parent
	self._shadowLifetimeTrove:Connect(self._button:GetPropertyChangedSignal("Visible"), function()
		dropShadow.Visible = self._button.Visible
	end)
	self._shadowLifetimeTrove:Connect(self._button:GetPropertyChangedSignal("Rotation"), function()
		dropShadow.Rotation = self._button.Rotation
	end)
	self._shadowLifetimeTrove:Connect(self._button:GetPropertyChangedSignal("Size"), function()
		dropShadow.Size = self._button.Size
	end)

	return dropShadow
end
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function GuiButtonClass.new(button: GuiButton, params: ButtonParams?): WrappedGuiButton
	assert(button:IsA("GuiButton"), "Must be a GuiButton!")
	local obj = GuiButtonClass:GetObjectByButton(button)
	if obj then
		return obj
	end
	local self = setmetatable({} :: self, MT)

	self._trove = Trove.new()
	self._shadowTrove = self._trove:Construct(Trove)
	self._shadowLifetimeTrove = self._trove:Construct(Trove)
	self._shimmerTrove = self._trove:Construct(Trove)
	self._button = button
	self._originalPosition = button.Position
	self._buttonProperties = {
		HoverTheme = getDefaultTheme(),
		SelectionTheme = getDefaultTheme(),
		AutoDeselect = if params and params.AutoDeselect ~= nil then params.AutoDeselect else false,
		OneClick = if params and params.OneClick ~= nil then params.OneClick else false,
		HoverSound = if params and params.HoverSound then params.HoverSound else DEFAULT_SOUNDS.HOVER,
		ClickSound = if params and params.ClickSound then params.ClickSound else DEFAULT_SOUNDS.CLICK,
	}
	self._shadowProperties = {
		XOffset = 0,
		YOffset = 0,
	}
	self._activeTweens = {
		Enter = {},
		Exit = {},
	}
	self._deselectGroup = "DEFAULT"

	-- conditions
	self._shimmerEnabled = false
	self._shadowEnabled = false
	self._isLocked = false
	self._isSelected = false
	self._isHovering = false
	self._debounce = false
	self._doClickSound = false
	self._doHoverSound = false
	self._hasActiveInput = false

	self.Signals = {
		Selected = self._trove:Add(Signal.new()),
		Deselected = self._trove:Add(Signal.new()),
		Activated = self._trove:Add(Signal.new()),
		MouseEnter = self._trove:Add(Signal.wrap(button.MouseEnter)),
		MouseLeave = self._trove:Add(Signal.wrap(button.MouseLeave)),
		InputBegan = self._trove:Add(Signal.wrap(button.InputBegan)),
		InputEnded = self._trove:Add(Signal.wrap(button.InputEnded)),
		InputChanged = self._trove:Add(Signal.wrap(button.InputChanged)),
	}

	self._trove:Connect(button.Activated, function(inputObj, clickCount)
		if self:IsLocked() then
			return
		end
		onButtonActivated(self, inputObj, clickCount)
	end)
	local shadowTweenMouseEnter, shadowTweenMouseLeave
	function shadowTweenMouseEnter()
		if not self._shadow or not self:IsShadowEnabled() then
			return
		end
		self._shadowTrove:Clean()

		local origPos = self._originalPosition
		local tween = TweenService:Create(self._button, TweenInfo.new(0.1), {
			Position = self._originalPosition
				+ UDim2.fromOffset(self._shadowProperties.XOffset, self._shadowProperties.YOffset),
		})
		self._shadowTrove:Add(function()
			if tween.PlaybackState == Enum.PlaybackState.Playing then
				tween:Cancel()
			end
		end)
		tween:Play()
		self._shadowTrove:Add(tween.Completed:Once(function(state)
			if state ~= Enum.PlaybackState.Completed then
				return
			end
			self._shadow.Visible = false
			if not self:HasActiveInput() then
				shadowTweenMouseLeave()
			end
		end))
	end

	function shadowTweenMouseLeave()
		if not self._shadow or not self:IsShadowEnabled() then
			return
		end
		self._shadowTrove:Clean()
		local tween = TweenService:Create(self._button, TweenInfo.new(0.1), { Position = self._originalPosition })
		self._shadowTrove:Add(function()
			if tween.PlaybackState == Enum.PlaybackState.Playing then
				tween:Cancel()
			end
		end)
		tween:Play()
		self._shadow.Visible = true
		self._shadowTrove:Add(tween.Completed:Once(function(state)
			if state ~= Enum.PlaybackState.Completed then
				return
			end
			if self:HasActiveInput() then
				shadowTweenMouseEnter()
			end
		end))
	end

	self._trove:Connect(button.InputBegan, function(input: InputObject)
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.Gamepad1
		then
			return
		end
		local usingTouch, touchObj = touch:IsUsingThumbstickControls()
		if usingTouch and touchObj then
			-- avoid if this input is actively interacting with thumbstick
			if input == touchObj then
				return
			end
		end
		if self:IsLocked() then
			return
		end
		if self:HasActiveInput() then
			-- This could likely be a second finger attempting to interact with the button, so ignore.
			logger:print("Ignoring other input on button.")
			return
		end
		self._hasActiveInput = true
		applyInputEnterTheme(self)

		if self:CanDoHoverSound() then
			FunctionUtils.Game.playSoundClone(self._buttonProperties.HoverSound, game:GetService("SoundService"))
		end

		if self._shadow and self:IsShadowEnabled() then
			shadowTweenMouseEnter()
		end

		if self._shimmer and self:IsShimmerEnabled() then
			self._shimmer.Visible = false
		end
	end)
	self._trove:Connect(button.InputEnded, function(input)
		if
			input.UserInputType ~= Enum.UserInputType.MouseMovement
			and input.UserInputType ~= Enum.UserInputType.Touch
			and input.UserInputType ~= Enum.UserInputType.Gamepad1
		then
			return
		end
		if not self:HasActiveInput() then
			return
		end
		self._hasActiveInput = false
		applyMouseLeaveTheme(self)
		if self._shadow and self:IsShadowEnabled() then
			shadowTweenMouseLeave()
		end

		if self._shimmer and self:IsShimmerEnabled() then
			self._shimmer.Visible = true
		end
	end)
	self._trove:Connect(button.Destroying, function()
		self:Destroy()
	end)

	table.insert(deselectGroups.DEFAULT, self)
	table.insert(buttonCache, self)

	return self
end

function GuiButtonClass:GetObjectByButton(button: GuiButton): WrappedGuiButton?
	for _, buttonObj in ipairs(buttonCache) do
		if buttonObj._button == button then
			return buttonObj
		end
	end
	return nil
end

function GuiButtonClass:GetDeselectGroupByName(name: string): { WrappedGuiButton }
	return if deselectGroups[name] then deselectGroups[name] else {}
end

function GuiButtonClass:GetSelectedButtons(): { WrappedGuiButton }
	local result = {}
	for _, button in ipairs(buttonCache) do
		if button:IsSelected() then
			table.insert(result, button)
		end
	end
	return result
end

function GuiButtonClass:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")
	return getmetatable(object).__index == MT
end

-----------------------------
-- CHAINABLE METHODS --
-----------------------------

-- Call a function within the method chain that is given the button object as an argument.
function MT.Call(self: WrappedGuiButton, callback: (buttonObj: WrappedGuiButton) -> ()): WrappedGuiButton
	task.spawn(callback, self)
	return self
end

function MT.ModifyTheme(
	self: WrappedGuiButton,
	which: "Hover" | "Selection",
	themeModification: ButtonThemeModification
): WrappedGuiButton
	local themeName = `{which}Theme`
	local currentTheme = self._buttonProperties[themeName] :: ButtonTheme
	local newTheme = FunctionUtils.Table.reconcile(themeModification, currentTheme) :: ButtonTheme

	for name, info in pairs(newTheme.EnterTweenInfo) do
		if not newTheme.ExitTweenInfo[name] then
			newTheme.ExitTweenInfo[name] = info
		end
	end
	for propertyName, _ in pairs(newTheme.Properties.Enter) do
		local button = self._button :: any -- fixes type annotation issue
		if not newTheme.Properties.Exit[propertyName] then
			newTheme.Properties.Exit[propertyName] = button[propertyName]
		end
	end

	self._buttonProperties[themeName] = newTheme
	return self
end

-- Places the button in a debounce state.
-- Prevents the button from being interacted with, including client and scripts.
function MT.Debounce(self: WrappedGuiButton, debounce: boolean?): WrappedGuiButton
	self._debounce = if debounce then debounce else false
	return self
end

-- <strong><code>!YIELDS!</code></strong>
-- Prevents the button from being interacted with (client and scripts) for the given <strong>duration</strong>.
function MT.DebounceYield(self: WrappedGuiButton, duration: number): WrappedGuiButton
	self._debounce = true
	task.wait(duration)
	self._debounce = false
	return self
end

function MT.ToggleShimmer(self: WrappedGuiButton, enable: boolean?, params: ShimmerParams?): WrappedGuiButton
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

function MT.ToggleDropShadow(self: WrappedGuiButton, enable: boolean?, params: ShadowParams?): WrappedGuiButton
	if enable and self:IsShadowEnabled() then
		return self
	elseif not enable and not self:IsShadowEnabled() then
		return self
	end

	local params = params or getDefaultShadowParams()
	self._shadowProperties.XOffset = params.XOffset
	self._shadowProperties.YOffset = params.YOffset

	self._shadowEnabled = if enable ~= nil then enable else false

	if self:IsShadowEnabled() then
		self._shadow = createDropShadow(self, params)
		self._shadowLifetimeTrove:Add(self._shadow)
	elseif self._shadow then
		self._shadowLifetimeTrove:Clean()
		self._shadow = nil
	end

	return self
end

-- Sound when the button is clicked?
function MT.ToggleClickSound(self: WrappedGuiButton, enable: boolean?): WrappedGuiButton
	self._doClickSound = if enable then true else false
	return self
end

-- Sound when the mouse hovers over the button?
function MT.ToggleHoverSound(self: WrappedGuiButton, enable: boolean?): WrappedGuiButton
	self._doHoverSound = if enable then true else false
	return self
end

function MT.ToggleAutoDeselect(self: WrappedGuiButton, enable: boolean?): WrappedGuiButton
	self._buttonProperties.AutoDeselect = if enable ~= nil then enable else false
	local numOfSelected = #GuiButtonClass:GetSelectedButtons()
	if enable and numOfSelected > 1 and self:IsSelected() then
		self:Deselect()
	end
	return self
end

-- Mark the button in a specific group for auto-deselect purposes
function MT.SetAutoDeselectGroup(self: WrappedGuiButton, groupName: string?): WrappedGuiButton
	local groupName = groupName or "DEFAULT"
	if not deselectGroups[groupName] then
		deselectGroups[groupName] = {}
	end

	for _, group in deselectGroups do
		local i = table.find(group, self)
		if i then
			table.remove(group, i)
		end
	end

	if self:IsSelected() then
		updateDeselectGroup(groupName)
	end
	self._deselectGroup = groupName
	table.insert(deselectGroups[groupName], self)
	return self
end

-- Makes the button immediately deselect when selected (acts as one click button)
function MT.ToggleOneClick(self: WrappedGuiButton, enable: boolean?): WrappedGuiButton
	self._buttonProperties.OneClick = if enable ~= nil then enable else false
	if enable and self:IsSelected() then
		self:Deselect()
	end
	return self
end

-- Stops user input from interacting with the button, but not scripts.
function MT.Lock(self: WrappedGuiButton): WrappedGuiButton
	self._isLocked = true
	return self
end

function MT.Unlock(self: WrappedGuiButton): WrappedGuiButton
	self._isLocked = false
	return self
end

function MT.Hide(self: WrappedGuiButton): WrappedGuiButton
	self._button.Visible = false
	return self
end

function MT.Unhide(self: WrappedGuiButton): WrappedGuiButton
	self._button.Visible = true
	return self
end

function MT.Select(
	self: WrappedGuiButton,
	userOverride: ("Player" | "Script")?,
	inputObj: InputObject?
): WrappedGuiButton
	if self:OnDebounce() then
		return self
	end
	if not self:IsOneClick() then
		-- Deselect others only when this button is not a one-click button.
		updateDeselectGroup(self._deselectGroup)
	end
	self._isSelected = true
	applySelectedTheme(self)
	self.Signals.Selected:FireDefer(userOverride or "Script", inputObj)
	return self
end

function MT.Deselect(
	self: WrappedGuiButton,
	userOverride: ("Player" | "Script")?,
	inputObj: InputObject?
): WrappedGuiButton
	if self:OnDebounce() then
		return self
	end
	self._isSelected = false
	applyDeselectedTheme(self)
	self.Signals.Deselected:FireDefer(userOverride or "Script", inputObj)
	return self
end

-- Manually activate the button through scripts. This bypasses input lock if the button is locked via <code>:Lock()</code>
-- You can optionally provide an <code>InputObject</code> if the button is being activated by client-input but needs to bypass the :Lock()
-- This does NOT bypass debounces.
function MT.Activate(self: WrappedGuiButton, inputObj: InputObject?): WrappedGuiButton
	onButtonActivated(self, nil, 1)
	return self
end

-- Shorthand for <code>:GetButton().Visible</code>
function MT.SetVisible(self: WrappedGuiButton, visible: boolean?): WrappedGuiButton
	self._button.Visible = visible or false
	return self
end

-- Shorthand for <code>:GetButton().AutoButtonColor</code>
function MT.SetAutoColor(self: WrappedGuiButton, auto: boolean?): WrappedGuiButton
	self._button.AutoButtonColor = auto or false
	return self
end

-----------------------------
-- REGULAR METHODS --
-----------------------------

function MT.GetButton(self: WrappedGuiButton): GuiButton
	return self._button
end

function MT.CanDoClickSound(self: WrappedGuiButton): boolean
	return self._doClickSound
end

function MT.CanDoHoverSound(self: WrappedGuiButton): boolean
	return self._doHoverSound
end

function MT.IsLocked(self: WrappedGuiButton): boolean
	return self._isLocked
end

function MT.IsHidden(self: WrappedGuiButton): boolean
	return self._button.Visible
end

function MT.IsMouseHovering(self: WrappedGuiButton): boolean
	return self._isHovering
end

function MT.IsAutoDeselect(self: WrappedGuiButton): boolean
	return self._buttonProperties.AutoDeselect
end

function MT.IsOneClick(self: WrappedGuiButton): boolean
	return self._buttonProperties.OneClick
end

-- Returns a boolean signifying if the button has an active input from the client.
function MT.HasActiveInput(self: WrappedGuiButton): boolean
	return self._hasActiveInput
end

function MT.IsShimmerEnabled(self: WrappedGuiButton): boolean
	return self._shimmerEnabled
end

function MT.IsShadowEnabled(self: WrappedGuiButton): boolean
	return self._shadowEnabled
end

function MT.IsSelected(self: WrappedGuiButton): boolean
	return self._isSelected
end

function MT.OnDebounce(self: WrappedGuiButton): boolean
	return self._debounce
end

function MT.Destroy(self: WrappedGuiButton)
	self._trove:Clean()
	local buttonIndex = table.find(buttonCache, self)
	if buttonIndex then
		table.remove(buttonCache, buttonIndex)
	end
	local groupIndex = table.find(deselectGroups[self._deselectGroup], self)
	if groupIndex then
		table.remove(deselectGroups[self._deselectGroup], groupIndex)
	end
end

-----------------------------
-- MAIN --
-----------------------------
return GuiButtonClass
