--!strict
--@author: crusherfire
--@date: 1/18/25
--[[@description:
	Wrapper class for SurfaceGuis that adds extra features.
	
	Features:
	- Ability to convert a SurfaceGui into a rotating SurfaceGui.
		- It will rotate to follow and look at the camera.
		- You can define rotation limits.
	
	Due to how this module works, changing the Enabled property of the SurfaceGui will no longer work.
	You must set an attribute 'IsEnabled' to toggle whether or not the SurfaceGui should render.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local FunctionUtils = require("../FunctionUtils")
local ModuleUtils = require("../ModuleUtils")
local RunService = game:GetService("RunService")
local t = FunctionUtils.t

-----------------------------
-- TYPES --
-----------------------------
-- For all of the properties/fields of an object made from this class.
type fields = {
	_trove: ModuleUtils.TroveType,
	_visibleTrove: ModuleUtils.TroveType,
	Signals: {
		GuiShown: ModuleUtils.SignalType<() -> (), ()>,
		GuiHidden: ModuleUtils.SignalType<() -> (), ()>,
	},
	_gui: SurfaceGui,
	_adorneeOrigCFrame: CFrame,

	_onHidingCallback: HidingCallback?,
	_maxDistance: number,
	_inRange: boolean,
	_rotationEnabled: boolean,
	_rotationLimits: RotationLimits?,
	_rotationSpring: ModuleUtils.Spring<Vector3>,
}

type RotationLimits = { X: NumberRange?, Y: NumberRange? }
type HidingCallback = (obj: WrappedSurfaceGui) -> ()

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT
export type WrappedSurfaceGui = typeof(setmetatable({} :: fields, MT))

local heartbeatConnection: RBXScriptConnection?
local objectCache = {}

-- CONSTANTS --
local DEFAULT_DAMPING = 0.85
local DEFAULT_SPEED = 16

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

local function onHeartbeat()
	for _, obj in ipairs(objectCache) do
		obj:_Step()
	end
end

local function getAdornee(gui: SurfaceGui): BasePart?
	local adornee = gui.Adornee or gui.Parent
	if not t.instanceIsA("BasePart")(adornee) then
		return
	end
	return adornee :: BasePart
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates a new WrappedSurfaceGui. The gui must have an adornee.
function Module.new(gui: SurfaceGui): WrappedSurfaceGui
	local adornee = getAdornee(gui)
	if not adornee then
		error(`surface gui: {gui} is missing adornee`, 2)
	end
	local self = setmetatable({} :: fields, MT)

	self._trove = ModuleUtils.Trove.new()
	self._visibleTrove = self._trove:Construct(ModuleUtils.Trove)
	self.Signals = {
		GuiShown = self._trove:Construct(ModuleUtils.Signal),
		GuiHidden = self._trove:Construct(ModuleUtils.Signal),
	}
	self._gui = gui
	self._maxDistance = gui.MaxDistance
	self._rotationEnabled = false
	self._inRange = false
	self._adorneeOrigCFrame = adornee.CFrame
	self._rotationSpring = ModuleUtils.Spring.new(Vector3.zero, DEFAULT_DAMPING, DEFAULT_SPEED)

	gui.MaxDistance = 0
	gui:SetAttribute("IsEnabled", gui.Enabled)
	gui.Enabled = false

	if not heartbeatConnection then
		heartbeatConnection = RunService.Heartbeat:Connect(onHeartbeat)
	end
	self._trove:Connect(gui:GetPropertyChangedSignal("MaxDistance"), function()
		if gui.MaxDistance == 0 then
			return
		end
		self._maxDistance = gui.MaxDistance
		gui.MaxDistance = 0
	end)
	self._trove:Connect(gui.Destroying, function()
		self:Destroy()
	end)

	table.insert(objectCache, self)
	return self
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	local mt = getmetatable(object)
	return mt ~= nil and mt.__index == MT
end

-- Enables the SurfaceGui to start rotating and looking at the player's camera.
-- Note: This will manipulate the CFrame of the adornee of the SurfaceGui.
-- <strong>rotationLimits</strong>: Optional limits for the rotation of the adornee (in radians). This limit is based on the adornee's starting orientation.
-- <strong>speed</strong>: Modify the speed of the spring responsible for rotation.
-- <strong>damping</strong>: Modify the damper of the spring responsible for rotation.
function MT.ToggleRotation(
	self: WrappedSurfaceGui,
	enable: boolean,
	rotationLimits: RotationLimits?,
	speed: number?,
	damping: number?
): WrappedSurfaceGui
	self._rotationEnabled = enable
	self._rotationLimits = rotationLimits

	if speed then
		self._rotationSpring.Speed = speed
	end
	if damping then
		self._rotationSpring.Damping = damping
	end

	return self
end

-- Allows you to set a function that will be called before the GUI is hidden. This callback may yield and the GUI will not hide
-- until the callback stops yielding. This is useful if you want to tween out the SurfaceGUI before it stops rendering.
-- If the GUI comes back into view/rendering before the callback finishes, the yielding thread will be cancelled.
-- Only one callback may be set!
function MT.SetOnHiding(self: WrappedSurfaceGui, callback: HidingCallback): WrappedSurfaceGui
	self._onHidingCallback = callback
	return self
end

function MT.GetGui(self: WrappedSurfaceGui): SurfaceGui
	return self._gui
end

function MT.GetAdornee(self: WrappedSurfaceGui): BasePart?
	return getAdornee(self._gui)
end

-- Is this SurfaceGui within range of the player's camera to be rendered?
function MT.InRange(self: WrappedSurfaceGui)
	return self._inRange
end

-- Returns if this GUI is rotating to look at the camera.
function MT.IsRotating(self: WrappedSurfaceGui)
	return self._rotationEnabled
end

function MT._Step(self: WrappedSurfaceGui)
	local gui = self:GetGui()
	local adornee = self:GetAdornee()
	if not adornee then
		return
	end
	if not gui:GetAttribute("IsEnabled") then
		return
	end
	local camera = workspace.CurrentCamera
	local cameraPosition = camera.CFrame.Position

	local checkPosition = adornee.Position
	local maxDistance = if self._maxDistance <= 0 then math.huge else self._maxDistance
	local magnitude = (cameraPosition - checkPosition).Magnitude

	if self:InRange() and magnitude > maxDistance then
		self._visibleTrove:Clean()
		self._visibleTrove:Add(task.spawn(function()
			self._inRange = false
			if self._onHidingCallback then
				self._onHidingCallback(self)
			end
			gui.Enabled = false
			self.Signals.GuiHidden:Fire()
		end))
	elseif not self:InRange() and magnitude <= maxDistance then
		self._visibleTrove:Clean()
		self._inRange = true
		gui.Enabled = true
		self.Signals.GuiShown:Fire()
	end

	if self:InRange() and self:IsRotating() then
		local lookCFrame = CFrame.lookAt(adornee.Position, camera.CFrame.Position)
		local targetX, targetY = lookCFrame:ToOrientation()
		local origX, origY, origZ = self._adorneeOrigCFrame:ToOrientation()

		local limits = self._rotationLimits
		local finalX = if limits and limits.X
			then FunctionUtils.Math.clampAngle(targetX, limits.X.Min, limits.X.Max, origX)
			else targetX
		local finalY = if limits and limits.Y
			then FunctionUtils.Math.clampAngle(targetY, limits.Y.Min, limits.Y.Max, origY)
			else targetY
		local finalZ = origZ

		self._rotationSpring.Target = Vector3.new(finalX, finalY, finalZ)
		local rot = self._rotationSpring.Position
		adornee.CFrame = CFrame.new(adornee.Position) * CFrame.fromOrientation(rot.X, rot.Y, rot.Z)
	end
end

function MT.Destroy(self: WrappedSurfaceGui)
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
