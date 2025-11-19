--!strict
--@author: crusherfire
--@date: 12/30/24
--[[@description:
	Useful utility functions for VFX
]]
-----------------------------
-- SERVICES --
-----------------------------
local TweenService = game:GetService("TweenService")

-----------------------------
-- DEPENDENCIES --
-----------------------------

-----------------------------
-- TYPES --
-----------------------------
local FastCastTypes = require("../ModuleUtils/_FastCastRedux/_FastCastTypes")

type BulletTrailData = {
	T0: number?,
	P0: Vector3?,
	V0: Vector3?,
	T1: number,
	P1: Vector3,
	V1: Vector3?,
	BulletSize: number,
	BulletBloom: number,
	BulletBrightness: number,
}

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}

local bulletTrail = script.BulletTracer
local rng = Random.new(tick())

local CAMERA = workspace.CurrentCamera

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Creates an explosion of unanchored parts.
-- <strong>force</strong>: Used to apply a direct force on the Y-axis and used for spread on X and Z axes.
-- <strong>sizeMultiplier</strong>: Randomly picks between the Min and Max to adjust the size of cloned parts from the template array.
function Module.explosion(templateParts: { BasePart }, origin: Vector3, force: number, count: number, sizeMultiplier: NumberRange?, collisionGroup: string?)
	local arrayLen = #templateParts
	assert(arrayLen > 0, "no parts found in array")
	local sizeMultiplier = sizeMultiplier or NumberRange.new(1)
	local spread = force * 1.25
	local tweenInfo = TweenInfo.new(0.75)
	for i = 1, count do
		local part = templateParts[rng:NextInteger(1, arrayLen)]:Clone()
		part.Name = "_explosionDebris"
		part.Parent = workspace
		part.Size = part.Size * rng:NextNumber(sizeMultiplier.Min, sizeMultiplier.Max)
		local tau = math.pi * 2
		part.CFrame = CFrame.new(origin) * CFrame.Angles(rng:NextNumber(0, tau), rng:NextNumber(0, tau), rng:NextInteger(0, tau))
		part.Anchored = false
		part.CanCollide = true
		part.CollisionGroup = collisionGroup or part.CollisionGroup
		part.Parent = workspace
		part:ApplyImpulse(Vector3.new(rng:NextNumber(-spread, spread), force, rng:NextNumber(-spread, spread)))
		task.delay(rng:NextNumber(3, 4), function()
			local tween = TweenService:Create(part, tweenInfo, { Size = Vector3.new(0.01, 0.01, 0.01) })
			tween:Play()
			tween.Completed:Wait()
			part:Destroy()
		end)
	end
end

-- Returns the bullet trail VFX to be used in a cast.
function Module.getBulletTrail()
	return bulletTrail
end

-- Adds <code>BulletTrailData</code> to the activeCast's <code>UserData</code> for use in <code>updateBulletTrail</code>.
function Module.createBulletTrailData(activeCast: FastCastTypes.ActiveCast, trailSize: number?, bloom: number?, brightness: number?): BulletTrailData
	local trailSize = trailSize or 0.2
	local bloom = bloom or 0.005
	local brightness = brightness or 1500
	local origin = activeCast:GetPosition()
	
	activeCast.UserData.BulletTrailData = {
		T0 = nil,
		P0 = nil,
		V0 = nil,
		T1 = os.clock(),
		P1 = CAMERA.CFrame:PointToObjectSpace(origin),
		V1 = nil,
		BulletSize = trailSize,
		BulletBloom = bloom,
		BulletBrightness = brightness,
	} :: BulletTrailData
	return activeCast.UserData.BulletTrailData
end

-- Call this each time the LengthChanged event fires for a caster. This dynamically changes the look of the beam for
-- the bullet trail to provide a realistic looking effect. The activeCast should have BulletTrailData and the correct CosmeticBulletObject!
function Module.updateBulletTrail(activeCast: FastCastTypes.ActiveCast, lastPosition: Vector3)
	assert(activeCast.UserData.BulletTrailData, "activeCast does not have BulletTrailData")
	assert(activeCast.RayInfo.CosmeticBulletObject, "missing CosmeticBulletObject")
	
	-- Calculate the new position of the beam attachments
	local trailData = activeCast.UserData.BulletTrailData :: BulletTrailData
	local cameraCFrame = CAMERA.CFrame
	local position = activeCast:GetPosition()
	local vfx = activeCast.RayInfo.CosmeticBulletObject :: any
	local attachment1: Attachment = vfx.Attachment1
	local attachment0: Attachment = vfx.Attachment0
	local beam: Beam = vfx.Beam
	
	local T2 = os.clock()
	local P2 = cameraCFrame:PointToObjectSpace(position)
	local V2
	if trailData.T0 then
		V2 = 2 / (T2 - trailData.T1) * (P2 - trailData.P1) - (P2 - trailData.P0) / (T2 - trailData.T0)
	else
		V2 = (P2 - trailData.P1) / (T2 - trailData.T1)
		trailData.V1 = V2
	end
	trailData.T0, trailData.V0, trailData.P0 = trailData.T1, trailData.V1, trailData.P1
	trailData.T1, trailData.V1, trailData.P1 = T2, V2, P2
	local deltaTime = trailData.T1 - trailData.T0 :: number
	local M0 = (trailData.V0 :: Vector3).Magnitude
	local M1 = (trailData.V1 :: Vector3).Magnitude
	attachment0.Position = cameraCFrame * trailData.P0
	attachment1.Position = cameraCFrame * trailData.P1
	if M0 > 1.0E-8 then
		attachment0.Axis = cameraCFrame:VectorToWorldSpace(trailData.V0 :: Vector3 / M0)
	end
	if M1 > 1.0E-8 then
		attachment1.Axis = cameraCFrame:VectorToWorldSpace(trailData.V1 :: Vector3 / M1)
	end
	local dist0 = -(trailData.P0 :: Vector3).Z
	local dist1 = -(trailData.P1 :: Vector3).Z
	dist0 = math.max(0, dist0)
	dist1 = math.max(0, dist1)
	local W0 = trailData.BulletSize + trailData.BulletBloom * dist0
	local W1 = trailData.BulletSize + trailData.BulletBloom * dist1
	local L = ((trailData.P1 :: Vector3 - trailData.P0 :: Vector3) * Vector3.new(1, 1, 0)).Magnitude
	local transparency = 1 - 4 * trailData.BulletSize * trailData.BulletSize / ((W0 + W1) * (2 * L + W0 + W1)) * trailData.BulletBrightness
	beam.CurveSize0 = deltaTime / 3 * M0
	beam.CurveSize1 = deltaTime / 3 * M1
	beam.Width0 = W0
	beam.Width1 = W1
	beam.Transparency = NumberSequence.new(transparency)
end

-- Tweens a blur in and out for impact effects.
function Module.blurFrame(fadeInTime: number, fadeOutTime: number, size: number)
	local blur = Instance.new("BlurEffect")
	blur.Name = "_VFXBlur"
	blur.Size = 0
	blur.Parent = workspace.CurrentCamera
	
	local t = TweenService:Create(blur, TweenInfo.new(fadeInTime), { Size = size })
	t:Play()
	
	t.Completed:Once(function()
		local t = TweenService:Create(blur, TweenInfo.new(fadeOutTime), { Size = 0 })
		t:Play()
		t.Completed:Once(function()
			task.wait(0.05)
			blur:Destroy()
		end)
	end)
end

function Module.colorFrame(fadeInTime: number, fadeOutTime: number, color: Color3)
	local colorCorrection = Instance.new("ColorCorrectionEffect")
	local white = Color3.new(1, 1, 1)
	colorCorrection.TintColor = white
	colorCorrection.Parent = workspace.CurrentCamera
	
	local t = TweenService:Create(colorCorrection, TweenInfo.new(fadeInTime), { TintColor = color })
	t:Play()

	t.Completed:Once(function()
		local t = TweenService:Create(colorCorrection, TweenInfo.new(fadeOutTime), { TintColor = white })
		t:Play()
		t.Completed:Once(function()
			task.wait(0.05)
			colorCorrection:Destroy()
		end)
	end)
end

-- Goes through <code>container</code>'s children and sets <code>.Enabled</code> to <code>enable</code>.
-- You can optionally include beams/trails and search through all descendants.
function Module.toggleAllEmitters(container: Instance, enable: boolean, includeBeams: boolean?, descendants: boolean?)
	local function handleChild(child: Instance)
		if child:IsA("ParticleEmitter") then
			child.Enabled = enable
		elseif includeBeams and (child:IsA("Beam") or child:IsA("Trail")) then
			(child :: any).Enabled = enable
		end
	end
	
	if descendants then
		for _, descendant in ipairs(container:GetDescendants()) do
			handleChild(descendant)
		end
	else
		for _, child in ipairs(container:GetChildren()) do
			handleChild(child)
		end
	end
end

-- Goes through the <code>container</code> and copies any child emitters into <code>target</code>.
-- <strong>copyAttachments</strong>: Optionally copy over any child attachments. If attachments are present and copied, then
-- <code>target</code> must be a BasePart! Otherwise, this function will error.
-- <strong>copyBeams</strong>: If true, will also automatically copy attachments. Attachment property references will be maintained.
-- Returns all copied child instances.
function Module.copyEmittersTo(container: Instance, target: Instance, copyAttachments: boolean?, copyBeams: boolean?): { any }
	local result: { any } = {}
	local dontClone: { [Instance]: boolean } = {}
	for _, child in ipairs(container:GetChildren()) do
		if 
			not (child:IsA("ParticleEmitter")
			or ((copyAttachments or copyBeams) and child:IsA("Attachment"))
			or (copyBeams and (child:IsA("Beam") or child:IsA("Trail"))))
		then
			continue
		end
		if dontClone[child] then
			continue
		end
		local clone = child:Clone() :: Instance
		
		if clone:IsA("Beam") or clone:IsA("Trail") then
			if clone.Attachment0 then
				local a0 = clone.Attachment0:Clone()
				dontClone[clone.Attachment0] = true
				a0.Parent = target;
				(clone :: any).Attachment0 = a0
				table.insert(result, a0)
			end
			if clone.Attachment1 then
				local a1 = clone.Attachment1:Clone();
				dontClone[clone.Attachment1] = true
				a1.Parent = target;
				(clone :: any).Attachment1 = a1
				table.insert(result, a1)
			end
		end
		
		clone.Parent = target
		table.insert(result, clone)
	end
	return result
end

-- Goes through the array and destroys the instances. Useful for cleaning up instances returned from <code>copyEmittersTo()</code>.
function Module.destroyVFX(instances: { any })
	for _, instance in ipairs(instances) do
		instance:Destroy()
	end
end

-- Emits the emitter according to <code>count</code> or <code>EmitCount</code> attribute or 1 by default.
function Module.emit(emitter: ParticleEmitter, count: number?)
	emitter:Emit(count or emitter:GetAttribute("EmitCount") or 1)
end

-- Goes through <code>container</code>'s children and emits particles from emitters based on their <code>EmitCount</code> attribute.
-- Also accounts for <code>EmitDelay</code> attribute (if it exists).
-- You can optionally search through all descendants.
function Module.emitAll(container: Instance, descendants: boolean?)
	local function handleChild(child: Instance)
		if child:IsA("ParticleEmitter") then
			local delay = child:GetAttribute("EmitDelay")
			local count = child:GetAttribute("EmitCount")
			if not count then
				warn(`emitter: {child} missing EmitCount attribute, defaulting to 1`)
				count = 1
			end
			if delay then
				task.delay(delay, function()
					child:Emit(count)
				end)
			else
				child:Emit(count)
			end
		end
	end
	
	if descendants then
		for _, descendant in ipairs(container:GetDescendants()) do
			handleChild(descendant)
		end
	else
		for _, child in ipairs(container:GetChildren()) do
			handleChild(child)
		end
	end
end

-----------------------------
-- MAIN --
-----------------------------
return Module