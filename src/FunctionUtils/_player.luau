--!strict
--@author: crusherfire
--@date: 11/7/24
--[[@description:

]]
-----------------------------
-- SERVICES --
-----------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AvatarEditorService = game:GetService("AvatarEditorService")

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Cache = require("../ModuleUtils/_Cache")
local _game = require("./_game")
local Future = require("../ModuleUtils/_Future")

-----------------------------
-- TYPES --
-----------------------------

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}

-- CONSTANTS --
local THUMBNAIL_TYPE = Enum.ThumbnailType.AvatarBust
local THUMBNAIL_SIZE = Enum.ThumbnailSize.Size100x100

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

--[[
	Evaluates if the player's character can be teleported (CFrame changed).
	- Must have character model
	- Must be alive
	- Must not be seated
]]
function Module.canTeleport(player: Player): (boolean, string?)
	local character = player.Character
	if not character then
		return false, "Player has no character model!"
	end
	local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then
		return false, "Player has no humanoid!"
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Seated then
		return false, "Can't teleport while seated!"
	end
	if humanoid:GetState() == Enum.HumanoidStateType.Dead then
		return false, "Can't teleport while dead!"
	end
	return true
end

function Module.getPlayerList(exclude: { Player }?): { Player }
	return _game.getPlayerList(exclude)
end

function Module.getRankInGroupFuture(player: Player, groupId: number)
	return Future.try(function()
		return player:GetRankInGroup(groupId)
	end)
end

--[[
	Client-only!
	Returns a Future if the player has favorited the game.
	Note: PromptReadAccess must be granted or this will fail
]]
function Module.hasFavoritedFuture()
	assert(RunService:IsClient(), "hasFavoritedFuture is client-only")
	return Future.try(function()
		return AvatarEditorService:GetFavorite(game.PlaceId, Enum.AvatarItemType.Asset)
	end)
end

do
	local inProgress = false
	
	--[[
		Client-only!
		Prompts the local player to favorite the game.
	]]
	function Module.promptFavoriteGame()
		if inProgress then
			return
		end
		inProgress = true
		AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		AvatarEditorService.PromptSetFavoriteCompleted:Once(function()
			inProgress = false
		end)
	end
end

-- Returns a Future containing an array of players who are friends with <code>player</code>.
function Module.getFriendsInGameFuture(player: Player)
	return Future.new(function()
		local playersInGame = Module.getPlayerList({ player })
		local futures = table.create(#playersInGame)

		for i, otherPlayer in ipairs(playersInGame) do
			futures[i] = Module.isFriendsWithFuture(player, otherPlayer)
		end

		local results = Future.all(futures):Await()
		local friends = {}

		for i, result in ipairs(results) do
			local success, isFriend = table.unpack(result)
			if success and isFriend then
				table.insert(friends, playersInGame[i])
			end
		end

		return friends
	end)
end

function Module.isFriendsWithFuture(player: Player, potentialFriend: Player)
	return Future.try(function(player: Player, potentialFriend: Player)
		return player:IsFriendsWith(potentialFriend.UserId)
	end, player, potentialFriend)
end

do
	local thumbnailTypeToString = {
		[Enum.ThumbnailType.HeadShot] = "AvatarHeadShot",
		[Enum.ThumbnailType.AvatarBust] = "AvatarBust",
		[Enum.ThumbnailType.AvatarThumbnail] = "Avatar"
	}
	local thumbnailSizeToPixels = {
		[Enum.ThumbnailSize.Size48x48] = 48,
		[Enum.ThumbnailSize.Size60x60] = 60,
		[Enum.ThumbnailSize.Size100x100] = 100,
		[Enum.ThumbnailSize.Size150x150] = 150,
		[Enum.ThumbnailSize.Size180x180] = 180,
		[Enum.ThumbnailSize.Size352x352] = 352,
		[Enum.ThumbnailSize.Size420x420] = 420,
	}
	
	-- Retrieves the player's thumbnail string content ID. This function does not yield unlike :GetUserThumbnailAsync()
	function Module.getPlayerThumbnail(userId: number, thumbnailType: Enum.ThumbnailType?, thumbnailSize: Enum.ThumbnailSize?): string
		local thumbnailType = thumbnailType or THUMBNAIL_TYPE
		local thumbnailSize = thumbnailSize or THUMBNAIL_SIZE

		local contentType = thumbnailTypeToString[thumbnailType]
		local pixelSize = thumbnailSizeToPixels[thumbnailSize]
		return `rbxthumb://type={contentType}&id={userId}&w={pixelSize}&h={pixelSize}`
	end
end

local usernameCache = Cache.new(1000)
-- <strong><code>!YIELDS!</code></strong>
-- Retrieves the player's username. Caches the result.
function Module.getPlayerUsername(userId: number): string?
	if not usernameCache:Get(userId) then
		local success, content = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		
		if success then
			usernameCache:Set(userId, content)
		end
	end
	
	return usernameCache:Get(userId)
end

-- A function that checks the network ownership of <code>part</code>. Safe to call from client & server unlike <code>:GetNetworkOwner()</code>.
-- If called from the server without the <code>player</code> argument, the server will check if it owns the part.
-- If called from the client, the local player will check if they have network ownership.
function Module.isNetworkOwner(part: BasePart, player: Player?): boolean
	if RunService:IsServer() then
		-- If player is nil, then the server is checking if the owner is itself.
		return if part:IsGrounded() then not player else part:GetNetworkOwner() == player
	else
		local assemblyRoot = part.AssemblyRootPart
		if not assemblyRoot then
			return false
		end
		return not part:IsGrounded() and (part.AssemblyRootPart :: BasePart).ReceiveAge == 0
	end
end

-- Indicates if the part(s) the motor influences are owned by the <code>player</code>.
function Module.ownsMotor6D(player: Player, motor: Motor6D): boolean
	if not motor.Part0 and not motor.Part1 then
		return false
	end
	if motor.Part0 and (not motor.Part0:IsDescendantOf(workspace) or not Module.isNetworkOwner(motor.Part0, player)) then
		return false
	end
	if motor.Part1 and (not motor.Part1:IsDescendantOf(workspace) or not Module.isNetworkOwner(motor.Part1, player)) then
		return false
	end
	return true
end

-----------------------------
-- MAIN --
-----------------------------
return Module