--!strict
--@author: crusherfire
--@date: 3/20/25
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local ModuleUtils = require("../ModuleUtils")
local FunctionUtils = require("../FunctionUtils")
local t = FunctionUtils.t

-----------------------------
-- TYPES --
-----------------------------
-- For all of the properties/fields of an object made from this class.
type fields = {
	_trove: ModuleUtils.TroveType,
	_flipbookTrove: ModuleUtils.TroveType,

	Signals: {
		FlipbookPaused: ModuleUtils.GenericSignal,
		FlipbookUnpaused: ModuleUtils.GenericSignal,
		FlipbookEnded: ModuleUtils.SignalType<(finished: boolean) -> (), (boolean)>,
	},

	_activeFlipbook: FlipbookParams?,
	_userData: { [any]: any },
	_imageLabel: ImageButton | ImageLabel,

	-- flags
	_flipbookPaused: boolean,
}

export type FlipbookParams = {
	ImageId: string,
	ImageResolution: number, -- 8x8, 16x16, 32x32, 64x64, 128x128, 256x256, 512x512, or 1024x1024
	Layout: Enum.ParticleFlipbookLayout,
	Mode: Enum.ParticleFlipbookMode,
	Framerate: number, -- FPS
	RepeatCount: number, -- -1 is infinite
	Direction: number?, -- -1 is backwards, 1 is forwards (default is 1)
	Reset: boolean?, -- should the frame reset back to default position when flipbook is over?
}
-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}
local MT = {}
MT.__index = MT
export type WrappedGuiImage = typeof(setmetatable({} :: fields, MT))

local rng = Random.new(tick())

-- CONSTANTS --

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- CLASS FUNCTIONS --
-----------------------------

function Module.new(image: ImageButton | ImageLabel): WrappedGuiImage
	local self = setmetatable({} :: fields, MT) :: WrappedGuiImage
	self._trove = ModuleUtils.Trove.new()
	self._flipbookTrove = self._trove:Construct(ModuleUtils.Trove)
	self.Signals = {
		FlipbookPaused = self._trove:Construct(ModuleUtils.Signal),
		FlipbookUnpaused = self._trove:Construct(ModuleUtils.Signal),
		FlipbookEnded = self._trove:Construct(ModuleUtils.Signal),
	}
	self._userData = {}

	self._imageLabel = image

	self._flipbookPaused = false

	self._trove:Connect(self._imageLabel.Destroying, function()
		self:Destroy()
	end)

	return self
end

function Module:BelongsToClass(object: any)
	assert(typeof(object) == "table", "Expected table for object!")

	local mt = getmetatable(object)
	return mt ~= nil and mt.__index == MT
end

-----------------------------
-- METHODS --
-----------------------------

-- Performs a flipbook animation on the image.
function MT.Flipbook(self: WrappedGuiImage, params: FlipbookParams): WrappedGuiImage
	-- Cleanup any previous flipbook tasks.
	self:CancelFlipbook()

	self._activeFlipbook = params
	local paramsDirection = params.Direction or 1
	local imageLabel = self._imageLabel :: ImageLabel
	imageLabel.Image = params.ImageId

	local gridSize
	do
		if params.Layout == Enum.ParticleFlipbookLayout.Grid2x2 then
			gridSize = 2
		elseif params.Layout == Enum.ParticleFlipbookLayout.Grid4x4 then
			gridSize = 4
		elseif params.Layout == Enum.ParticleFlipbookLayout.Grid8x8 then
			gridSize = 8
		else
			warn(`Invalid layout: {params.Layout}`)
			return self
		end
	end

	local gridResolution = params.ImageResolution / gridSize
	imageLabel.ImageRectSize = Vector2.new(gridResolution, gridResolution)
	local totalFrames = gridSize * gridSize
	local waitDuration = 1 / params.Framerate

	local currentIteration = 0
	local frameCount = 0

	local direction = paramsDirection
	local currentFrame = if direction == 1 then 1 else totalFrames
	local finished = false

	self._flipbookTrove:Add(task.spawn(function()
		while true do
			local column = ((currentFrame - 1) % gridSize) + 1
			local row = math.floor((currentFrame - 1) / gridSize) + 1
			imageLabel.ImageRectOffset = Vector2.new((column - 1) * gridResolution, (row - 1) * gridResolution)

			if params.Mode == Enum.ParticleFlipbookMode.Random then
				currentFrame = rng:NextInteger(1, totalFrames)
				if frameCount % totalFrames == 0 then
					currentIteration += 1
				end
			elseif params.Mode == Enum.ParticleFlipbookMode.PingPong then
				-- For PingPong, use the current direction (which may have been flipped)
				currentFrame = currentFrame + direction
				if currentFrame > totalFrames then
					-- Overshot the last frame, so reverse (and avoid a duplicate)
					currentFrame = totalFrames - 1
					direction = -direction
				elseif currentFrame < 1 then
					-- Overshot before the first frame; reverse and count an iteration.
					currentFrame = 2
					direction = -direction
					currentIteration += 1
				end
			elseif params.Mode == Enum.ParticleFlipbookMode.Loop then
				-- Move sequentially based on the provided Direction.
				currentFrame = currentFrame + paramsDirection
				if currentFrame > totalFrames then
					currentIteration += 1
					currentFrame = 1
				elseif currentFrame < 1 then
					currentIteration += 1
					currentFrame = totalFrames
				end
			else
				-- OneShot
				currentFrame = currentFrame + paramsDirection
				if currentFrame > totalFrames then
					currentIteration += 1
					currentFrame = if params.RepeatCount ~= -1 and currentIteration >= params.RepeatCount
						then totalFrames
						else 1
				elseif currentFrame < 1 then
					currentIteration += 1
					currentFrame = if params.RepeatCount ~= -1 and currentIteration >= params.RepeatCount
						then 1
						else totalFrames
				end
			end

			frameCount += 1

			task.wait(waitDuration)
			if self._flipbookPaused then
				self.Signals.FlipbookUnpaused:Wait()
			end

			if params.RepeatCount ~= -1 and currentIteration >= params.RepeatCount then
				if params.Reset then
					local currentFrame = 1
					local column = ((currentFrame - 1) % gridSize) + 1
					local row = math.floor((currentFrame - 1) / gridSize) + 1
					imageLabel.ImageRectOffset = Vector2.new((column - 1) * gridResolution, (row - 1) * gridResolution)
				end
				break
			end
		end
		finished = true
		self.Signals.FlipbookEnded:Fire(finished)
	end))

	self._flipbookTrove:Add(function()
		if not finished then
			self.Signals.FlipbookEnded:Fire(finished)
		end
	end)

	return self
end

-- Pauses any active flipbook animations.
function MT.PauseFlipbook(self: WrappedGuiImage)
	self._flipbookPaused = true
	self.Signals.FlipbookPaused:FireDefer()
end

-- Resumes any active flipbook animations.
function MT.UnpauseFlipbook(self: WrappedGuiImage)
	self._flipbookPaused = false
	self.Signals.FlipbookUnpaused:FireDefer()
end

-- Cancels any active flipbook.
-- <strong>reset</strong>: Resets offset back to starting position (0, 0).
function MT.CancelFlipbook(self: WrappedGuiImage, reset: boolean?)
	if not self._activeFlipbook then
		return
	end
	if reset then
		(self._imageLabel :: any).ImageRectOffset = Vector2.zero
	end
	self._flipbookTrove:Clean()
	self._activeFlipbook = nil
end

-----------------------------
-- SETTERS --
-----------------------------

-----------------------------
-- GETTERS --
-----------------------------

function MT.GetImage(self: WrappedGuiImage): ImageLabel | ImageButton
	return self._imageLabel
end

function MT.GetTrove(self: WrappedGuiImage): ModuleUtils.TroveType
	return self._trove
end

function MT.GetUserData(self: WrappedGuiImage): { [any]: any }
	return self._userData
end

-----------------------------
-- CLEANUP --
-----------------------------

function MT.Destroy(self: WrappedGuiImage)
	self._trove:Clean()
end

-----------------------------
-- MAIN --
-----------------------------
return Module
