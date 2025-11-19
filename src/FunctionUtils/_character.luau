--!nonstrict
local Module = {}
local Players = game:GetService("Players")
local t = require("./_t")


-- Relative move direction tells you if the humanoid is moving left/right/forward/backward no matter
-- what direction they're moving in global space
function Module.getRelativeHumanoidMoveDirection(humanoid: Humanoid)
	local rootPart = humanoid.RootPart :: BasePart
	if not rootPart then
		warn("Humanoid has no root part")
		return Vector3.new()
	end
	return rootPart.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
end

-- Returns a boolean if the humanoid can jump by normal means.
-- The humanoid must be within the valid humanoid states and the <code>Jumping</code> state must be enabled.
function Module.canJump(humanoid: Humanoid): boolean
	local myState = humanoid:GetState()
	if
		(myState == Enum.HumanoidStateType.Running
		or myState == Enum.HumanoidStateType.Swimming
		or myState == Enum.HumanoidStateType.Seated
		or myState == Enum.HumanoidStateType.Climbing)
		and humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
	then
		return true
	end
	return false
end

function Module.isHumanoidMoving(humanoid: Humanoid): (boolean, Vector3)
	local isMoving = humanoid.MoveDirection.Magnitude > 0
	return isMoving, humanoid.MoveDirection
end

function Module.isHumanoidDead(humanoid: Humanoid): boolean
	if humanoid:GetState() == Enum.HumanoidStateType.Dead or humanoid.Health <= 0 then
		return true
	end
	return false
end

function Module.onGround(humanoid: Humanoid): (boolean, Enum.Material)
	local onGround = humanoid.FloorMaterial ~= Enum.Material.Air
	return onGround, humanoid.FloorMaterial
end

function Module.getCharacterFromDescendant(descendant: Instance): Model?
	local currentInstance = descendant.Parent

	while currentInstance do
		if currentInstance:IsA("Model") and currentInstance:FindFirstChildWhichIsA("Humanoid") then
			return currentInstance
		end

		currentInstance = currentInstance.Parent
	end

	return nil
end

function Module.getRigAnimator(rig: Instance): Animator?
	assert(rig, "Specified rig does not exist")

	local animationController = rig:FindFirstChildWhichIsA("Humanoid") or rig:FindFirstChildWhichIsA("AnimationController")
	if animationController then
		local animator = animationController:FindFirstChildWhichIsA("Animator")
		if animator then
			return animator
		end
	end
	return nil
end

function Module.createRigAnimator(rig: Instance): Animator
	assert(rig, "Specified rig does not exist")

	local animationController = rig:FindFirstChildWhichIsA("Humanoid") or rig:FindFirstChildWhichIsA("AnimationController")
	if not animationController then
		animationController = Instance.new("AnimationController")
		animationController.Parent = rig
	end

	local animator = animationController:FindFirstChildWhichIsA("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = animationController
	end

	return animator
end

function Module.loadPlay(animator: Animator, animation: number | string | Animation, ...: any): AnimationTrack
	assert(animator and typeof(animator) == "Instance", "animator is invalid or nil")
	assert(animation, "animation is invalid or nil")

	local animationResult
	if typeof(animation) == "number" then
		animationResult = Instance.new("Animation")
		animationResult.AnimationId = "rbxassetid://" ..animation
	elseif typeof(animation) == "string" then
		animationResult = Instance.new("Animation")
		animationResult.AnimationId =  animation
	elseif typeof(animation) == "Instance" then
		animationResult = animation
	end

	local loadedAnimation = animator:LoadAnimation(animationResult)
	loadedAnimation:Play(...)

	return loadedAnimation
end

function Module.load(animator: Animator, animation: number | string | Animation)
	assert(animator and typeof(animator) == "Instance", "animator is invalid or nil")
	assert(animation, "animation is invalid or nil")

	local animationResult
	if typeof(animation) == "number" then
		animationResult = Instance.new("Animation")
		animationResult.AnimationId = "rbxassetid://" ..animation
	elseif typeof(animation) == "string" then
		animationResult = Instance.new("Animation")
		animationResult.AnimationId =  animation
	elseif typeof(animation) == "Instance" then
		animationResult = animation
	end

	local loadedAnimation = animator:LoadAnimation(animationResult)
	return loadedAnimation
end

function Module.waitForAnimTrackToLoad(animTrack: AnimationTrack, timeOut: number?): boolean
	-- There is no built-in way to see if an animation track loads and
	-- property signals don't fire for .Length!
	-- Roblox Moment! :/
	if animTrack.Length > 0 then
		return false
	end
	local currentThread = coroutine.running()
	task.defer(function()
		local start = os.clock()
		while true do
			if animTrack.Length > 0 then
				if coroutine.status(currentThread) == "suspended" then
					task.spawn(currentThread, false)
				end
				return
			elseif timeOut and os.clock() - start >= timeOut then
				if coroutine.status(currentThread) == "suspended" then
					task.spawn(currentThread, false)
				end
				return
			end
			task.wait()
		end
	end)
	return coroutine.yield()
end

function Module.getRootPart(descendant: Instance): BasePart?
	local humanoid = Module.getHumanoid(descendant)
	return humanoid.RootPart
end

function Module.getHumanoid(descendant: Instance): Humanoid?
	local character = Module.getCharacterFromDescendant(descendant)
	if not character then
		return nil
	end
	return character:FindFirstChildOfClass("Humanoid")
end

function Module.getAliveHumanoid(descendant: Instance): Humanoid?
	local humanoid = Module.getHumanoid(descendant)
	return if humanoid and humanoid.Health > 0 then humanoid else nil
end

function Module.getPlayerHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

--[=[
	Gets a player's humanoid, and ensures it is alive, otherwise returns nil
	@param player Player
	@return Humanoid? -- Nil if not found
]=]
function Module.getAlivePlayerHumanoid(player: Player): Humanoid?
	local humanoid = Module.getPlayerHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid
end

--[=[
	Gets a player's humanoid's rootPart, and ensures the humanoid is alive, otherwise
	returns nil
	@param player Player
	@return BasePart? -- Nil if not found
]=]
function Module.getAlivePlayerRootPart(player: Player): BasePart?
	local humanoid = Module.getPlayerHumanoid(player)
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end

	return humanoid.RootPart
end

-- Client-only!
-- Gets a local player from a descendant otherwise returns nil
function Module.getLocalPlayerFromCharacter(descendant: Instance): Player?
	local player = Module.getPlayerFromCharacter(descendant)
	if player == Players.LocalPlayer then
		return player
	end
	return
end

--[=[
	Gets a player's humanoid's rootPart otherwise returns nil
	@param player Player
	@return BasePart? -- Nil if not found
]=]
function Module.getPlayerRootPart(player: Player): BasePart?
	local humanoid = Module.getPlayerHumanoid(player)
	if not humanoid then
		return nil
	end

	return humanoid.RootPart
end

--[=[
	Unequips all tools for a give player's humanomid, if the humanoid
	exists

	```lua
	local Players = game:GetService("Players")

	for _, player in pairs(Players:GetPlayers()) do
		Character.unequipTools(player)
	end
	```

	@param player Player
]=]
function Module.unequipTools(player: Player)
	local humanoid = Module.getPlayerHumanoid(player)
	if humanoid then
		humanoid:UnequipTools()
	end
end

--[=[
	Returns the player that a descendent is part of, if it is part of one.

	```lua
	script.Parent.Touched:Connect(function(inst)
		local player = Character.getPlayerFromCharacter(inst)
		if player then
			-- activate button!
		end
	end)
	```

	:::tip
	This method is useful in a ton of different situations. For example, you can
	use it on classes bound to a humanoid, to determine the player. You can also
	use it to determine, upon touched events, if a part is part of a character.
	:::

	@param descendant Instance -- A child of the potential character.
	@return Player? -- Nil if not found
]=]
function Module.getPlayerFromCharacter(descendant: Instance): Player?
	if typeof(descendant) ~= "Instance" then
		error("invalid descendant", 2)
	end
	local character = descendant
	local player = Players:GetPlayerFromCharacter(character)

	while not player do
		if character.Parent then
			character = character.Parent
			player = Players:GetPlayerFromCharacter(character)
		else
			return nil
		end
	end

	return player
end

function Module.applyDescriptionFromUserId(userId: number, humanoid: Humanoid)
	assert(t.numberMin(1)(userId))
	assert(t.instanceIsA("Humanoid")(humanoid))
	
	local success, result = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(userId)
	end)

	assert(success, "Failed to get humanoid description")

	humanoid:ApplyDescriptionReset(result)
end

local INVISIBLE_TAG = "UTIL_INVISIBLE"
local INVISIBLE_ATTR_NAME = "UTIL_INVISIBLE_ATTR"

--[[
	Useful to make all visible parts invisible and stores their visibility on the model
]]
function Module.makeCharacterInvisible(character: Model)
	for _, descendent in ipairs(character:GetDescendants()) do
		if not descendent:IsA("BasePart") then
			continue
		end
		
		if descendent.Transparency < 1 then
			descendent:SetAttribute(INVISIBLE_ATTR_NAME, descendent.Transparency)
			descendent.Transparency = 1
		end
	end
end

function Module.makeCharacterVisible(character: Model)
	for _, descendent in ipairs(character:GetDescendants()) do
		if not descendent:IsA("BasePart") then
			continue
		end
		
		if descendent:GetAttribute(INVISIBLE_ATTR_NAME) then
			descendent.Transparency = descendent:GetAttribute(INVISIBLE_ATTR_NAME)
			
			descendent:SetAttribute(INVISIBLE_ATTR_NAME, nil)
		end
	end
end

return Module