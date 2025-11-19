--!strict
--@author: crusherfire
--@date: 1/15/24
--[[@description:
	Wrapper class for Billboard GUIs that adds extra features.
	
	Features:
	- Ability to have billboard GUIs appear on the screen edges when looking away from them.
		- Works only for offset-size billboards since trying to put scale into the mix will cause problems.
		- In practice, this is a screen GUI placed on the screen.
		- Changed event is supported. No support for ChildAdded/Removed
	- Extra events, such as when the GUI is displayed or hidden.
	- Add an optional yieldable callback that executes right before the GUI is disabled to perform tweens.
	
	Due to how this module works, changing the Enabled property of the billboard will no longer work.
	You must set an attribute 'IsEnabled' to toggle whether or not the billboard should render.
]]
-----------------------------
-- SERVICES --
-----------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local ModuleUtils = require("../ModuleUtils")
local FunctionUtils = require("../FunctionUtils")
local Trove = ModuleUtils.Trove
local Signal = ModuleUtils.Signal
local t = FunctionUtils.t

-----------------------------
-- TYPES --
-----------------------------
-- This is for all of the properties of an object made from this class for type annotation purposes.
type HidingCallback = (obj: WrappedBillboardGui) -> ()

type self = {
	Signals: {
		GuiShown: ModuleUtils.SignalType<() -> (), ()>, -- fired when the gui is shown
		GuiHidden: ModuleUtils.SignalType<() -> (), ()>, -- fired after the gui is hidden
		RenderModeChanged: ModuleUtils.SignalType<() -> (), ()>,
		StayOnScreenChanged: ModuleUtils.SignalType<() -> (), ()>,
		RotationLimitChanged: ModuleUtils.SignalType<() -> (), ()>,
	},
	_trove: ModuleUtils.TroveType,
	_visibleTrove: ModuleUtils.TroveType, -- cleaned when gui is shown or hidden
	_onHidingCallback: HidingCallback?,
	_gui: BillboardGui,

	_adorneePos: Vector3,
	_billboardRenderPos: Vector3,
	_renderMode: RenderMode,
	_maxDistance: number,
	_inRange: boolean,
	_stayOnScreen: boolean,
	_stayOnScreenFrame: Frame?,
}

type RenderMode = "DEFAULT" | "BILLBOARD"
type CompatibleAdornees = BasePart | Model | Attachment

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT
export type WrappedBillboardGui = typeof(setmetatable({} :: self, MT))

local objectCache: { WrappedBillboardGui } = {}
local stayOnScreenGui = script.StayOnScreenBillboards
local renderStepConnection: RBXScriptConnection?

-- CONSTANTS --
local CAMERA = workspace.CurrentCamera
local PLAYER = Players.LocalPlayer

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- Copies everything from one instance to the other instance.
-- This also listens to the Changed signal for all instances in <code>from</code> and updates the corresponding instance in <code>to</code>
-- Returns a trove for cleaning up connections.
local function deepCopyAndListen(from: Instance, to: Instance, _trove: ModuleUtils.TroveType?): ModuleUtils.TroveType
	if not _trove then
		_trove = ModuleUtils.Trove.new()
	end
	assert(_trove, "expected trove")
	for _, child: Instance in pairs(from:GetChildren()) do
		local newChild: Instance = child:Clone()
		newChild.Parent = to

		local connections = deepCopyAndListen(child, newChild, _trove)

		_trove:Connect(child.Changed, function(property)
			pcall(function()
				(newChild :: any)[property] = (child :: any)[property]
			end)
		end)
	end

	return _trove :: any
end

local function getAdornee(gui: BillboardGui): CompatibleAdornees?
	local adornee = gui.Adornee or gui.Parent
	if
		t.instanceIsA("BasePart")(adornee)
		or t.instanceIsA("Model")(adornee)
		or t.instanceIsA("Attachment")(adornee)
	then
		return adornee :: any
	end
	return
end

local function getAdorneeCFrame(adornee: CompatibleAdornees): CFrame
	if adornee:IsA("BasePart") then
		return adornee.CFrame
	elseif adornee:IsA("Model") then
		-- Bounding box center is used by billboard GUIs
		local cf, _ = adornee:GetBoundingBox()
		return cf
	elseif adornee:IsA("Attachment") then
		return adornee.WorldCFrame
	end
	error("Invalid adornee")
end

local function onRenderStep()
	debug.profilebegin("WRAPPED_BILLBOARD_UPDATE")
	if #objectCache == 0 and renderStepConnection then
		renderStepConnection:Disconnect()
		renderStepConnection = nil
		return
	end
	local cameraPosition = CAMERA.Focus.Position -- this is the RENDERING position
	for _, obj in ipairs(objectCache) do
		obj:_Step(cameraPosition)
	end
	debug.profileend()
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates a new WrappedBillboardGui.
function Module.new(gui: BillboardGui): WrappedBillboardGui
	assert(typeof(gui) == "Instance" and gui:IsA("BillboardGui"), "Expected BillboardGui!")
	local myTrove = Trove.new()
	local adornee = getAdornee(gui)
	local self: self = {
		_trove = myTrove,
		_visibleTrove = myTrove:Construct(Trove),
		Signals = {
			GuiShown = myTrove:Construct(Signal),
			GuiHidden = myTrove:Construct(Signal),
			RenderModeChanged = myTrove:Construct(Signal),
			StayOnScreenChanged = myTrove:Construct(Signal),
			RotationLimitChanged = myTrove:Construct(Signal),
		},

		_gui = gui,
		_adorneePos = if adornee then getAdorneeCFrame(adornee).Position else Vector3.zero,
		_billboardRenderPos = FunctionUtils.Math.getBillboardWorldPosition(gui) or Vector3.zero,
		_renderMode = "DEFAULT",
		_maxDistance = gui.MaxDistance,
		_inRange = false,
		_stayOnScreen = false,
	}
	setmetatable(self, MT)

	gui.MaxDistance = 0
	gui:SetAttribute("IsEnabled", gui.Enabled)
	gui.Enabled = false

	myTrove:Connect(gui:GetPropertyChangedSignal("MaxDistance"), function()
		if gui.MaxDistance == 0 then
			return
		end
		self._maxDistance = gui.MaxDistance
		gui.MaxDistance = 0
	end)

	if not renderStepConnection then
		renderStepConnection = RunService.RenderStepped:Connect(onRenderStep)
	end

	self._trove:Add(gui.Destroying:Once(function()
		self:Destroy()
	end))

	table.insert(objectCache, self)
	return self
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	return getmetatable(object).__index == MT
end

-- Allows you to set a function that will be called before the GUI is hidden. This callback may yield and the GUI will not hide
-- until the callback stops yielding. This is useful if you want to tween out the billboard GUI before it stops rendering.
-- If the GUI comes back into view/rendering before the callback finishes, the yielding thread will be cancelled.
-- Only one callback may be set!
function MT.SetOnHiding(self: WrappedBillboardGui, callback: HidingCallback): WrappedBillboardGui
	self._onHidingCallback = callback
	return self
end

-- Defines the point where the <code>MaxDistance</code> is calculated from.
-- 'DEFAULT' mode is the position of the adornee.
-- 'BILLBOARD' mode is the position the billboard is being rendered in the world.
function MT.SetRenderMode(self: WrappedBillboardGui, mode: RenderMode): WrappedBillboardGui
	local old = self._renderMode
	self._renderMode = mode
	if old ~= self._renderMode then
		self.Signals.RenderModeChanged:Fire()
	end
	return self
end

-- Determines if the billboard GUI should clamp along the edges of the screen when <code>:GetBillboardPosition()</code> goes off-screen.
-- Only works for billboard GUI's with Offset size.
function MT.SetStayOnScreen(self: WrappedBillboardGui, stayOnScreen: boolean): WrappedBillboardGui
	local size = self:GetBillboard().Size
	if size.X.Offset == 0 and size.Y.Offset == 0 then
		warn("Unable to :SetStayOnScreen() on incompatible billboard")
		return self
	end
	local old = self._stayOnScreen
	self._stayOnScreen = stayOnScreen
	if old ~= self._stayOnScreen then
		self.Signals.StayOnScreenChanged:Fire()
	end
	return self
end

function MT.StayOnScreen(self: WrappedBillboardGui): boolean
	return self._stayOnScreen
end

function MT.GetRenderMode(self: WrappedBillboardGui): RenderMode
	return self._renderMode
end

function MT.GetBillboard(self: WrappedBillboardGui): BillboardGui
	return self._gui
end

-- Returns the world position of where the billboard is being rendered.
function MT.GetBillboardPosition(self: WrappedBillboardGui): Vector3
	return self._billboardRenderPos
end

-- Return the world position of the adornee used for calculating the final position of the billboard.
function MT.GetAdorneePosition(self: WrappedBillboardGui): Vector3
	return self._adorneePos
end

function MT.GetAdornee(self: WrappedBillboardGui): CompatibleAdornees?
	local gui = self:GetBillboard()
	return getAdornee(gui)
end

-- Is this billboard within range of the player's camera to be rendered?
function MT.InRange(self: WrappedBillboardGui)
	return self._inRange
end

function MT._Step(self: WrappedBillboardGui, cameraPosition: Vector3)
	local billboard = self:GetBillboard()
	local adornee = self:GetAdornee()
	if not adornee then
		return
	end
	if not billboard:GetAttribute("IsEnabled") then
		return
	end
	self._adorneePos = getAdorneeCFrame(adornee).Position
	self._billboardRenderPos = FunctionUtils.Math.getBillboardWorldPosition(billboard) :: Vector3

	local checkPosition = if self:GetRenderMode() == "DEFAULT"
		then self:GetAdorneePosition()
		else self:GetBillboardPosition()
	local maxDistance = if self._maxDistance <= 0 then math.huge else self._maxDistance
	local magnitude = (cameraPosition - checkPosition).Magnitude

	if self:InRange() and magnitude > maxDistance then
		self._visibleTrove:Clean()
		self._visibleTrove:Add(task.spawn(function()
			self._inRange = false
			if self._onHidingCallback then
				self._onHidingCallback(self)
			end
			billboard.Enabled = false
			self.Signals.GuiHidden:Fire()
		end))
	elseif not self:InRange() and magnitude <= maxDistance then
		self._visibleTrove:Clean()
		self._inRange = true
		billboard.Enabled = true
		self.Signals.GuiShown:Fire()
	end

	local stayFrame = self:_GetStayOnScreenFrame()
	if self:StayOnScreen() and self:InRange() then
		stayOnScreenGui.Parent = PLAYER.PlayerGui

		local framePos, wasClamped = FunctionUtils.Camera.toClampedScreenSpace(
			self:GetBillboardPosition(),
			Vector2.new(stayFrame.Size.X.Offset / 2, stayFrame.Size.Y.Offset / 2)
		)

		if wasClamped then
			stayFrame.Position = UDim2.fromOffset(framePos.X, framePos.Y)
			-- funky bug (roblox moment): --
			-- https://devforum.roblox.com/t/frames-are-rendered-at-previous-position-when-visibility-is-enabled/2930768
			local _ = stayFrame.AbsolutePosition
			-- --
			stayFrame.Visible = true
			billboard.Enabled = false
		else
			billboard.Enabled = true
			stayFrame.Visible = false
		end
	elseif stayFrame.Visible then
		if self:InRange() then
			billboard.Enabled = true
		end
		stayFrame.Visible = false
	end

	-- TODO: Migrate to a potential SurfaceGui wrapper class --
	--[[local guiPart, surfaceGui = self:_GetRotLimitGui()
	if self:IsRotationLimited() and self:InRange() then
		billboard.Enabled = false
		surfaceGui.Enabled = true
		guiPart.CFrame = CFrame.new(self:GetBillboardPosition()) * FunctionUtils.CFrame.getLookRotation("Y", self:GetBillboardPosition(), CAMERA.CFrame.Position)
	elseif surfaceGui.Enabled then
		if self:InRange() then
			billboard.Enabled = true
		end
		surfaceGui.Enabled = false
	end]]
end

function MT._GetStayOnScreenFrame(self: WrappedBillboardGui): Frame
	if not self._stayOnScreenFrame then
		local frame = Instance.new("Frame")
		frame.Size = self:GetBillboard().Size
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.BackgroundTransparency = 1
		frame.Visible = false
		local cleanup = deepCopyAndListen(self:GetBillboard(), frame)
		frame.Parent = stayOnScreenGui
		cleanup:Connect(self.Signals.StayOnScreenChanged, function()
			if not self:StayOnScreen() then
				cleanup:Clean()
				frame:Destroy()
				self._stayOnScreenFrame = nil
			end
		end)
		self._stayOnScreenFrame = frame
	end
	return self._stayOnScreenFrame :: Frame
end

function MT.Destroy(self: WrappedBillboardGui)
	self._trove:Clean()
	local i = table.find(objectCache, self)
	if i then
		table.remove(objectCache, i)
	end
end

-----------------------------
-- MAIN --
-----------------------------
return Module
