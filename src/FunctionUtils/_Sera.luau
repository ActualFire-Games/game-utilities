--!strict
--!native

--[[
MAD STUDIO

-[Sera]---------------------------------------

	Low-level schematized serialization library

	Members:

		Sera.Boolean

		Sera.Uint8
		Sera.Uint16
		Sera.Uint32
		Sera.Int8
		Sera.Int16
		Sera.Int32
		Sera.Float32
		Sera.Float64

		Sera.CFrame -- 48 bytes; Full precision
		Sera.LossyCFrame -- 28 bytes; Less than 0.0005 degree precision error for rotation
		Sera.Vector3
		Sera.Color3
		Sera.ColorV3 -- Input and output are Vector3's with [0, 1] color values

		Sera.String8  -- Max 255 size
		Sera.String16 -- Max 65,535 size
		Sera.String32 -- Max 4,294,967,295 size

		Sera.Buffer8  -- Max 255 size
		Sera.Buffer16 -- Max 65,535 size
		Sera.Buffer32 -- Max 4,294,967,295 size
		
		Sera.Angle8 -- (Unsigned) Radian representation in one byte while preserving cardinal direction accuracy (Every 45 degrees)

	Functions:

		Sera.Schema(params): Schema -- Maximum 255 fields
			params:
				{
					["FieldName"]: SeraType,
					...
				}

		-- "Serialize", "Push", "DeltaSerialize" and "DeltaPush" will return first argument if succeeded,
		-- Or return an error message as the second argument if failed.

		-- When all fields are present (Non-schema fields are ignored; Missing fields will throw an error):

		Sera.Deserialize(schema: Schema, b: buffer, offset: number?): ({[string]: any}, offset: number)
		Sera.Serialize(schema: Schema, t: {[string]: any}): (buffer?, err: string?)
		Sera.Push(schema: Schema, t: {[string]: any}, b: buffer, offset: number?): (offset: number?, err: string?)

		-- When only some fields are present (Non-schema fields will throw an error):

		Sera.DeltaDeserialize(schema: Schema, b: buffer, offset: number?): ({[string]: any}, offset: number)
		Sera.DeltaSerialize(schema: Schema, t: {[string]: any}): (buffer?, err: string?)
		Sera.DeltaPush(schema: Schema, t: {[string]: any}, b: buffer, offset: number?): (offset: number?, err: string?)

		-- Delta serialization has an additional size cost of (n + 1) bytes where "n" is the number of fields present
		-- in a table that's being serialized (1 byte for present field count, 1 enumerating byte for each field)

--]]

local BIG_BUFFER_SIZE = 1000000 -- "Serialize" and "DeltaSerialize" will fail if resulting buffer size is larger than this value

local SIZE_8 = 2 ^ 8 - 1
local SIZE_16 = 2 ^ 16 - 1
local SIZE_32 = 2 ^ 32 - 1

local MAX_FIELDS = 2 ^ 8 - 1

local BB = buffer.create(BIG_BUFFER_SIZE) -- Big reusable buffer

----- Public -----

export type Ser = (b: buffer, offset: number, value: any) -> (number)
export type Des = (b: buffer, offset: number) -> (any, number)

export type SeraType = {
	Name: string,
	Ser: Ser,
	Des: Des,
}

type Field = {Key: string, Name: string, Ser: Ser, Des: Des, Index: number}

export type Schema = {
	Numeric: {Field},
	String: {[string]: Field},
}

local Sera = {
	BB = BB,
}

Sera.Boolean = table.freeze({
	Name = "Boolean",
	Ser = function(b: buffer, offset: number, value: boolean): number
		if value == true then
			buffer.writeu8(b, offset, 1)
		elseif value == false then
			buffer.writeu8(b, offset, 0)
		else
			error("Expected boolean")
		end
		return offset + 1
	end,
	Des = function(b: buffer, offset: number): (boolean, number)
		return buffer.readu8(b, offset) == 1, offset + 1
	end,
})

Sera.Uint8 = table.freeze({
	Name = "Uint8",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writeu8(b, offset, value)
		return offset + 1
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readu8(b, offset), offset + 1
	end,
})

Sera.Uint16 = table.freeze({
	Name = "Uint16",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writeu16(b, offset, value)
		return offset + 2
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readu16(b, offset), offset + 2
	end,
})

Sera.Uint32 = table.freeze({
	Name = "Uint32",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writeu32(b, offset, value)
		return offset + 4
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readu32(b, offset), offset + 4
	end,
})

Sera.Int8 = table.freeze({
	Name = "Int8",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writei8(b, offset, value)
		return offset + 1
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readi8(b, offset), offset + 1
	end,
})

Sera.Int16 = table.freeze({
	Name = "Int16",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writei16(b, offset, value)
		return offset + 2
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readi16(b, offset), offset + 2
	end,
})

Sera.Int32 = table.freeze({
	Name = "Int32",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writei32(b, offset, value)
		return offset + 4
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readi32(b, offset), offset + 4
	end,
})

Sera.Float32 = table.freeze({
	Name = "Float32",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writef32(b, offset, value)
		return offset + 4
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readf32(b, offset), offset + 4
	end,
})

Sera.Float64 = table.freeze({
	Name = "Float64",
	Ser = function(b: buffer, offset: number, value: number): number
		buffer.writef64(b, offset, value)
		return offset + 8
	end,
	Des = function(b: buffer, offset: number): (number, number)
		return buffer.readf64(b, offset), offset + 8
	end,
})

Sera.CFrame = table.freeze({
	Name = "CFrame",
	Ser = function(b: buffer, offset: number, value: CFrame): number
		local v0, v1, v2, v3, v4, v5, v6, v7, v8, v9, v10, v11 = value:GetComponents()
		buffer.writef32(b, offset, v0)
		buffer.writef32(b, offset + 4, v1)
		buffer.writef32(b, offset + 8, v2)
		buffer.writef32(b, offset + 12, v3)
		buffer.writef32(b, offset + 16, v4)
		buffer.writef32(b, offset + 20, v5)
		buffer.writef32(b, offset + 24, v6)
		buffer.writef32(b, offset + 28, v7)
		buffer.writef32(b, offset + 32, v8)
		buffer.writef32(b, offset + 36, v9)
		buffer.writef32(b, offset + 40, v10)
		buffer.writef32(b, offset + 44, v11)
		return offset + 48
	end,
	Des = function(b: buffer, offset: number): (CFrame, number)
		return CFrame.new(
			buffer.readf32(b, offset),
			buffer.readf32(b, offset + 4),
			buffer.readf32(b, offset + 8),
			buffer.readf32(b, offset + 12),
			buffer.readf32(b, offset + 16),
			buffer.readf32(b, offset + 20),
			buffer.readf32(b, offset + 24),
			buffer.readf32(b, offset + 28),
			buffer.readf32(b, offset + 32),
			buffer.readf32(b, offset + 36),
			buffer.readf32(b, offset + 40),
			buffer.readf32(b, offset + 44)
		), offset + 48
	end,
})

Sera.LossyCFrame = table.freeze({
	Name = "LossyCFrame",
	Ser = function(b: buffer, offset: number, value: CFrame): number
		local axis, angle = value:ToAxisAngle()
		buffer.writef32(b, offset, value.X)
		buffer.writef32(b, offset + 4, value.Y)
		buffer.writef32(b, offset + 8, value.Z)
		buffer.writef32(b, offset + 12, axis.X)
		buffer.writef32(b, offset + 16, axis.Y)
		buffer.writef32(b, offset + 20, axis.Z)
		buffer.writef32(b, offset + 24, angle)
		return offset + 28
	end,
	Des = function(b: buffer, offset: number): (CFrame, number)
		return CFrame.fromAxisAngle(
			Vector3.new(
				buffer.readf32(b, offset + 12),
				buffer.readf32(b, offset + 16),
				buffer.readf32(b, offset + 20)
			),
			buffer.readf32(b, offset :: number + 24)
		)
			+ Vector3.new(
				buffer.readf32(b, offset),
				buffer.readf32(b, offset + 4),
				buffer.readf32(b, offset + 8)
			), offset + 28
	end,
})

Sera.Vector3 = table.freeze({
	Name = "Vector3",
	Ser = function(b: buffer, offset: number, value: Vector3): number
		buffer.writef32(b, offset, value.X)
		buffer.writef32(b, offset + 4, value.Y)
		buffer.writef32(b, offset + 8, value.Z)
		return offset + 12
	end,
	Des = function(b: buffer, offset: number): (Vector3, number)
		return Vector3.new(
			buffer.readf32(b, offset),
			buffer.readf32(b, offset + 4),
			buffer.readf32(b, offset + 8)
		), offset + 12
	end,
})

Sera.Color3 = table.freeze({
	Name = "Color3",
	Ser = function(b: buffer, offset: number, value: Color3): number
		buffer.writeu8(b, offset, value.R * 255)
		buffer.writeu8(b, offset + 1, value.G * 255)
		buffer.writeu8(b, offset + 2, value.B * 255)
		return offset + 3
	end,
	Des = function(b: buffer, offset: number): (Color3, number)
		return Color3.fromRGB(
			buffer.readu8(b, offset),
			buffer.readu8(b, offset + 1),
			buffer.readu8(b, offset + 2)
		), offset + 3
	end,
})

Sera.ColorV3 = table.freeze({
	Name = "ColorV3",
	Ser = function(b: buffer, offset: number, value: Vector3): number
		buffer.writeu8(b, offset, value.X * 255)
		buffer.writeu8(b, offset + 1, value.Y * 255)
		buffer.writeu8(b, offset + 2, value.Z * 255)
		return offset + 3
	end,
	Des = function(b: buffer, offset: number): (Vector3, number)
		return Vector3.new(
			buffer.readu8(b, offset) / 255,
			buffer.readu8(b, offset + 1) / 255,
			buffer.readu8(b, offset + 2) / 255
		), offset + 3
	end,
})

-- Handles strings up to 255 characters long.
Sera.String8 = table.freeze({
	Name = "String8",
	Ser = function(b: buffer, offset: number, value: string): number
		local length = value:len()
		if length > SIZE_8 then
			error(`String too long`)
		end
		buffer.writeu8(b, offset, length)
		buffer.writestring(b, offset + 1, value)
		return offset + 1 + length
	end,
	Des = function(b: buffer, offset: number): (string, number)
		local length = buffer.readu8(b, offset)
		return buffer.readstring(b, offset + 1, length), offset + 1 + length
	end,
})

-- Handles strings up to 65,535 characters long.
Sera.String16 = table.freeze({
	Name = "String16",
	Ser = function(b: buffer, offset: number, value: string): number
		local length = value:len()
		if length > SIZE_16 then
			error(`String too long`)
		end
		buffer.writeu16(b, offset, length)
		buffer.writestring(b, offset + 2, value)
		return offset + 2 + length
	end,
	Des = function(b: buffer, offset: number): (string, number)
		local length = buffer.readu16(b, offset)
		return buffer.readstring(b, offset + 2, length), offset + 2 + length
	end,
})

-- Handles strings up to (2^32 - 1) characters long.
Sera.String32 = table.freeze({
	Name = "String32",
	Ser = function(b: buffer, offset: number, value: string): number
		local length = value:len()
		if length > SIZE_32 then
			error(`String too long`)
		end
		buffer.writeu32(b, offset, length)
		buffer.writestring(b, offset + 4, value)
		return offset + 4 + length
	end,
	Des = function(b: buffer, offset: number): (string, number)
		local length = buffer.readu32(b, offset)
		return buffer.readstring(b, offset + 4, length), offset + 4 + length
	end,
})

do
	-- some enums don't exist on Roblox client
	local enumTypeToIndex: { [string]: number } =  {
		["AccessModifierType"] = 1,
		["AccessoryType"] = 2,
		["ActionOnAutoResumeSync"] = 3,
		["ActionOnStopSync"] = 4,
		["ActionType"] = 5,
		["ActuatorRelativeTo"] = 6,
		["ActuatorType"] = 7,
		["AdAvailabilityResult"] = 8,
		["AdEventType"] = 9,
		["AdFormat"] = 10,
		["AdShape"] = 11,
		["AdTeleportMethod"] = 12,
		["AdUIEventType"] = 13,
		["AdUIType"] = 14,
		["AdUnitStatus"] = 15,
		["AdornCullingMode"] = 16,
		["AlignType"] = 17,
		["AlphaMode"] = 18,
		["AnalyticsCustomFieldKeys"] = 19,
		["AnalyticsEconomyAction"] = 20,
		["AnalyticsEconomyFlowType"] = 21,
		["AnalyticsEconomyTransactionType"] = 22,
		["AnalyticsLogLevel"] = 23,
		["AnalyticsProgressionStatus"] = 24,
		["AnalyticsProgressionType"] = 25,
		["AnimationClipFromVideoStatus"] = 26,
		["AnimationPriority"] = 27,
		["AnimatorRetargetingMode"] = 28,
		["AnnotationEditingMode"] = 29,
		["AnnotationRequestStatus"] = 30,
		["AnnotationRequestType"] = 31,
		["AppLifecycleManagerState"] = 32,
		["AppShellActionType"] = 33,
		["AppShellFeature"] = 34,
		["AppUpdateStatus"] = 35,
		["ApplyStrokeMode"] = 36,
		["AspectType"] = 37,
		["AssetCreatorType"] = 38,
		["AssetFetchStatus"] = 39,
		["AssetType"] = 40,
		["AssetTypeVerification"] = 41,
		["AudioApiRollout"] = 42,
		["AudioCaptureMode"] = 43,
		["AudioChannelLayout"] = 44,
		["AudioFilterType"] = 45,
		["AudioSimulationFidelity"] = 46,
		["AudioSubType"] = 47,
		["AudioWindowSize"] = 48,
		["AuthorityMode"] = 49,
		["AutoIndentRule"] = 50,
		["AutomaticSize"] = 51,
		["AvatarAssetType"] = 52,
		["AvatarChatServiceFeature"] = 53,
		["AvatarContextMenuOption"] = 54,
		["AvatarGenerationError"] = 55,
		["AvatarItemType"] = 56,
		["AvatarPromptResult"] = 57,
		["AvatarSettingsAccessoryLimitMethod"] = 58,
		["AvatarSettingsAccessoryMode"] = 59,
		["AvatarSettingsAnimationClipsMode"] = 60,
		["AvatarSettingsAnimationPacksMode"] = 61,
		["AvatarSettingsAppearanceMode"] = 62,
		["AvatarSettingsBuildMode"] = 63,
		["AvatarSettingsClothingMode"] = 64,
		["AvatarSettingsCollisionMode"] = 65,
		["AvatarSettingsCustomAccessoryMode"] = 66,
		["AvatarSettingsCustomBodyType"] = 67,
		["AvatarSettingsCustomClothingMode"] = 68,
		["AvatarSettingsHitAndTouchDetectionMode"] = 69,
		["AvatarSettingsJumpMode"] = 70,
		["AvatarSettingsLegacyCollisionMode"] = 71,
		["AvatarSettingsScaleMode"] = 72,
		["AvatarThumbnailCustomizationType"] = 73,
		["AvatarUnificationMode"] = 74,
		["Axis"] = 75,
		["BenefitType"] = 76,
		["BinType"] = 77,
		["BodyPart"] = 78,
		["BodyPartR15"] = 79,
		["BorderMode"] = 80,
		["BreakReason"] = 81,
		["BreakpointRemoveReason"] = 82,
		["BulkMoveMode"] = 83,
		["BundleType"] = 84,
		["Button"] = 85,
		["ButtonStyle"] = 86,
		["CageType"] = 87,
		["CameraMode"] = 88,
		["CameraPanMode"] = 89,
		["CameraSpeedAdjustBinding"] = 90,
		["CameraType"] = 91,
		["CaptureType"] = 92,
		["CatalogCategoryFilter"] = 93,
		["CatalogSortAggregation"] = 94,
		["CatalogSortType"] = 95,
		["CellBlock"] = 96,
		["CellMaterial"] = 97,
		["CellOrientation"] = 98,
		["CenterDialogType"] = 99,
		["CharacterControlMode"] = 100,
		["ChatCallbackType"] = 101,
		["ChatColor"] = 102,
		["ChatMode"] = 103,
		["ChatPrivacyMode"] = 104,
		["ChatRestrictionStatus"] = 105,
		["ChatStyle"] = 106,
		["ChatVersion"] = 107,
		["ClientAnimatorThrottlingMode"] = 108,
		["CloseReason"] = 109,
		["CollaboratorStatus"] = 110,
		["CollisionFidelity"] = 111,
		["CommandPermission"] = 112,
		["CompileTarget"] = 113,
		["CompletionAcceptanceBehavior"] = 114,
		["CompletionItemKind"] = 115,
		["CompletionItemTag"] = 116,
		["CompletionTriggerKind"] = 117,
		["ComputerCameraMovementMode"] = 118,
		["ComputerMovementMode"] = 119,
		["ConfigSnapshotErrorState"] = 120,
		["ConnectionError"] = 121,
		["ConnectionState"] = 122,
		["ContentSourceType"] = 123,
		["ContextActionPriority"] = 124,
		["ContextActionResult"] = 125,
		["ControlMode"] = 126,
		["CoreGuiType"] = 127,
		["CreateAssetResult"] = 128,
		["CreateOutfitFailure"] = 129,
		["CreatorType"] = 130,
		["CreatorTypeFilter"] = 131,
		["CurrencyType"] = 132,
		["CustomCameraMode"] = 133,
		["DataStoreRequestType"] = 134,
		["DebuggerEndReason"] = 135,
		["DebuggerExceptionBreakMode"] = 136,
		["DebuggerFrameType"] = 137,
		["DebuggerPauseReason"] = 138,
		["DebuggerStatus"] = 139,
		["DevCameraOcclusionMode"] = 140,
		["DevComputerCameraMovementMode"] = 141,
		["DevComputerMovementMode"] = 142,
		["DevTouchCameraMovementMode"] = 143,
		["DevTouchMovementMode"] = 144,
		["DeveloperMemoryTag"] = 145,
		["DeviceFeatureType"] = 146,
		["DeviceForm"] = 147,
		["DeviceLevel"] = 148,
		["DeviceType"] = 149,
		["DialogBehaviorType"] = 150,
		["DialogPurpose"] = 151,
		["DialogTone"] = 152,
		["DisplaySize"] = 153,
		["DominantAxis"] = 154,
		["DraftStatusCode"] = 155,
		["DragDetectorDragStyle"] = 156,
		["DragDetectorPermissionPolicy"] = 157,
		["DragDetectorResponseStyle"] = 158,
		["DraggerCoordinateSpace"] = 159,
		["DraggerMovementMode"] = 160,
		["DraggingScrollBar"] = 161,
		["EasingDirection"] = 162,
		["EasingStyle"] = 163,
		["EditableStatus"] = 164,
		["ElasticBehavior"] = 165,
		["EnviromentalPhysicsThrottle"] = 166,
		["ExperienceAuthScope"] = 167,
		["ExplosionType"] = 168,
		["FACSDataLod"] = 169,
		["FacialAgeEstimationResultType"] = 170,
		["FacialAnimationStreamingState"] = 171,
		["FacsActionUnit"] = 172,
		["FieldOfViewMode"] = 173,
		["FillDirection"] = 174,
		["FilterErrorType"] = 175,
		["FilterResult"] = 176,
		["FinishRecordingOperation"] = 177,
		["FluidFidelity"] = 178,
		["FluidForces"] = 179,
		["Font"] = 180,
		["FontSize"] = 181,
		["FontStyle"] = 182,
		["FontWeight"] = 183,
		["ForceLimitMode"] = 184,
		["FormFactor"] = 185,
		["FrameStyle"] = 186,
		["FramerateManagerMode"] = 187,
		["FriendRequestEvent"] = 188,
		["FriendStatus"] = 189,
		["FunctionalTestResult"] = 190,
		["GameAvatarType"] = 191,
		["GamepadType"] = 192,
		["GearGenreSetting"] = 193,
		["GearType"] = 194,
		["Genre"] = 195,
		["GraphicsMode"] = 196,
		["GraphicsOptimizationMode"] = 197,
		["GuiState"] = 198,
		["GuiType"] = 199,
		["HandRigDescriptionSide"] = 200,
		["HandlesStyle"] = 201,
		["HapticEffectType"] = 202,
		["HighlightDepthMode"] = 203,
		["HorizontalAlignment"] = 204,
		["HoverAnimateSpeed"] = 205,
		["HttpCachePolicy"] = 206,
		["HttpCompression"] = 207,
		["HttpContentType"] = 208,
		["HttpError"] = 209,
		["HttpRequestType"] = 210,
		["HumanoidCollisionType"] = 211,
		["HumanoidDisplayDistanceType"] = 212,
		["HumanoidHealthDisplayType"] = 213,
		["HumanoidRigType"] = 214,
		["HumanoidStateType"] = 215,
		["IKCollisionsMode"] = 216,
		["IKControlConstraintSupport"] = 217,
		["IKControlType"] = 218,
		["IXPLoadingStatus"] = 219,
		["ImageAlphaType"] = 220,
		["ImageCombineType"] = 221,
		["InOut"] = 222,
		["InfoType"] = 223,
		["InitialDockState"] = 224,
		["InputActionType"] = 225,
		["InputType"] = 226,
		["IntermediateMeshGenerationResult"] = 227,
		["InterpolationThrottlingMode"] = 228,
		["InviteState"] = 229,
		["ItemLineAlignment"] = 230,
		["JoinSource"] = 231,
		["JointCreationMode"] = 232,
		["KeyCode"] = 233,
		["KeyInterpolationMode"] = 234,
		["KeywordFilterType"] = 235,
		["Language"] = 236,
		["LeftRight"] = 237,
		["LexemeType"] = 238,
		["LightingStyle"] = 239,
		["Limb"] = 240,
		["LineJoinMode"] = 241,
		["ListDisplayMode"] = 242,
		["ListenerLocation"] = 243,
		["ListenerType"] = 244,
		["LiveEditingAtomicUpdateResponse"] = 245,
		["LiveEditingBroadcastMessageType"] = 246,
		["LoadCharacterLayeredClothing"] = 247,
		["LoadDynamicHeads"] = 248,
		["LocationType"] = 249,
		["LuauTypeCheckMode"] = 250,
		["MarketplaceBulkPurchasePromptStatus"] = 251,
		["MarketplaceItemPurchaseStatus"] = 252,
		["MarketplaceProductType"] = 253,
		["MarkupKind"] = 254,
		["MatchmakingType"] = 255,
		["Material"] = 256,
		["MaterialPattern"] = 257,
		["MembershipType"] = 258,
		["MeshPartDetailLevel"] = 259,
		["MeshPartHeadsAndAccessories"] = 260,
		["MeshScaleUnit"] = 261,
		["MeshType"] = 262,
		["MessageType"] = 263,
		["ModelLevelOfDetail"] = 264,
		["ModelStreamingBehavior"] = 265,
		["ModelStreamingMode"] = 266,
		["ModerationStatus"] = 267,
		["ModifierKey"] = 268,
		["MouseBehavior"] = 269,
		["MoveState"] = 270,
		["MoverConstraintRootBehaviorMode"] = 271,
		["MuteState"] = 272,
		["NameOcclusion"] = 273,
		["NegateOperationHiddenHistory"] = 274,
		["NetworkOwnership"] = 275,
		["NetworkStatus"] = 276,
		["NoiseType"] = 277,
		["NormalId"] = 278,
		["NotificationButtonType"] = 279,
		["OperationType"] = 280,
		["OrientationAlignmentMode"] = 281,
		["OutfitSource"] = 282,
		["OutfitType"] = 283,
		["OutputLayoutMode"] = 284,
		["OverrideMouseIconBehavior"] = 285,
		["PackagePermission"] = 286,
		["PartType"] = 287,
		["ParticleEmitterShape"] = 288,
		["ParticleEmitterShapeInOut"] = 289,
		["ParticleEmitterShapeStyle"] = 290,
		["ParticleFlipbookLayout"] = 291,
		["ParticleFlipbookMode"] = 292,
		["ParticleFlipbookTextureCompatible"] = 293,
		["ParticleOrientation"] = 294,
		["PathStatus"] = 295,
		["PathWaypointAction"] = 296,
		["PathfindingUseImprovedSearch"] = 297,
		["PermissionLevelShown"] = 298,
		["PhysicsSimulationRate"] = 299,
		["PhysicsSteppingMethod"] = 300,
		["Platform"] = 301,
		["PlaybackState"] = 302,
		["PlayerActions"] = 303,
		["PlayerCharacterDestroyBehavior"] = 304,
		["PlayerChatType"] = 305,
		["PlayerDataErrorState"] = 306,
		["PlayerDataLoadFailureBehavior"] = 307,
		["PoseEasingDirection"] = 308,
		["PoseEasingStyle"] = 309,
		["PositionAlignmentMode"] = 310,
		["PredictionMode"] = 311,
		["PreferredInput"] = 312,
		["PreferredTextSize"] = 313,
		["PrimalPhysicsSolver"] = 314,
		["PrimitiveType"] = 315,
		["PrivilegeType"] = 316,
		["ProductLocationRestriction"] = 317,
		["ProductPurchaseChannel"] = 318,
		["ProductPurchaseDecision"] = 319,
		["PromptCreateAssetResult"] = 320,
		["PromptCreateAvatarResult"] = 321,
		["PromptLinkSharingResult"] = 322,
		["PromptPublishAssetResult"] = 323,
		["PropertyStatus"] = 324,
		["ProximityPromptExclusivity"] = 325,
		["ProximityPromptInputType"] = 326,
		["ProximityPromptStyle"] = 327,
		["QualityLevel"] = 328,
		["R15CollisionType"] = 329,
		["RaycastFilterType"] = 330,
		["RecommendationActionType"] = 331,
		["RecommendationImpressionType"] = 332,
		["RecommendationItemVisibility"] = 333,
		["RejectCharacterDeletions"] = 334,
		["RenderFidelity"] = 335,
		["RenderPriority"] = 336,
		["RenderingCacheOptimizationMode"] = 337,
		["RenderingTestComparisonMethod"] = 338,
		["ReplicateInstanceDestroySetting"] = 339,
		["ResamplerMode"] = 340,
		["ReservedHighlightId"] = 341,
		["RestPose"] = 342,
		["ReturnKeyType"] = 343,
		["ReverbType"] = 344,
		["RibbonTool"] = 345,
		["RigScale"] = 346,
		["RigType"] = 347,
		["RollOffMode"] = 348,
		["RolloutState"] = 349,
		["RotationOrder"] = 350,
		["RotationType"] = 351,
		["RsvpStatus"] = 352,
		["RtlTextSupport"] = 353,
		["RunContext"] = 354,
		["RunState"] = 355,
		["RuntimeUndoBehavior"] = 356,
		["SafeAreaCompatibility"] = 357,
		["SalesTypeFilter"] = 358,
		["SandboxedInstanceMode"] = 359,
		["SaveAvatarThumbnailCustomizationFailure"] = 360,
		["SaveFilter"] = 361,
		["SavedQualitySetting"] = 362,
		["ScaleType"] = 363,
		["ScopeCheckResult"] = 364,
		["ScreenInsets"] = 365,
		["ScreenOrientation"] = 366,
		["ScrollBarInset"] = 367,
		["ScrollingDirection"] = 368,
		["SecurityCapability"] = 369,
		["SelectionBehavior"] = 370,
		["SelectionRenderMode"] = 371,
		["SelfViewPosition"] = 372,
		["SensorMode"] = 373,
		["SensorUpdateType"] = 374,
		["ServerLiveEditingMode"] = 375,
		["ServiceVisibility"] = 376,
		["Severity"] = 377,
		["ShowAdResult"] = 378,
		["SignalBehavior"] = 379,
		["SizeConstraint"] = 380,
		["SolverConvergenceMetricType"] = 381,
		["SolverConvergenceVisualizationMode"] = 382,
		["SortDirection"] = 383,
		["SortOrder"] = 384,
		["SpecialKey"] = 385,
		["StartCorner"] = 386,
		["StateObjectFieldType"] = 387,
		["Status"] = 388,
		["StreamOutBehavior"] = 389,
		["StreamingIntegrityMode"] = 390,
		["StreamingPauseMode"] = 391,
		["StudioCloseMode"] = 392,
		["StudioDataModelType"] = 393,
		["StudioPlaceUpdateFailureReason"] = 394,
		["StudioScriptEditorColorCategories"] = 395,
		["StudioScriptEditorColorPresets"] = 396,
		["StudioStyleGuideColor"] = 397,
		["StudioStyleGuideModifier"] = 398,
		["Style"] = 399,
		["SubscriptionExpirationReason"] = 400,
		["SubscriptionPaymentStatus"] = 401,
		["SubscriptionPeriod"] = 402,
		["SubscriptionState"] = 403,
		["SurfaceConstraint"] = 404,
		["SurfaceGuiShape"] = 405,
		["SurfaceGuiSizingMode"] = 406,
		["SurfaceType"] = 407,
		["SwipeDirection"] = 408,
		["SystemThemeValue"] = 409,
		["TableMajorAxis"] = 410,
		["TeamCreateErrorState"] = 411,
		["Technology"] = 412,
		["TeleportMethod"] = 413,
		["TeleportResult"] = 414,
		["TeleportState"] = 415,
		["TeleportType"] = 416,
		["TerrainAcquisitionMethod"] = 417,
		["TerrainFace"] = 418,
		["TextChatMessageStatus"] = 419,
		["TextDirection"] = 420,
		["TextFilterContext"] = 421,
		["TextInputType"] = 422,
		["TextTruncate"] = 423,
		["TextXAlignment"] = 424,
		["TextYAlignment"] = 425,
		["TextureMode"] = 426,
		["TextureQueryType"] = 427,
		["ThreadPoolConfig"] = 428,
		["ThrottlingPriority"] = 429,
		["ThumbnailSize"] = 430,
		["ThumbnailType"] = 431,
		["TickCountSampleMethod"] = 432,
		["TonemapperPreset"] = 433,
		["TopBottom"] = 434,
		["TouchCameraMovementMode"] = 435,
		["TouchMovementMode"] = 436,
		["TrackerError"] = 437,
		["TrackerExtrapolationFlagMode"] = 438,
		["TrackerFaceTrackingStatus"] = 439,
		["TrackerLodFlagMode"] = 440,
		["TrackerLodValueMode"] = 441,
		["TrackerMode"] = 442,
		["TrackerPromptEvent"] = 443,
		["TrackerType"] = 444,
		["TriStateBoolean"] = 445,
		["TweenStatus"] = 446,
		["UICaptureMode"] = 447,
		["UIDragDetectorBoundingBehavior"] = 448,
		["UIDragDetectorDragRelativity"] = 449,
		["UIDragDetectorDragSpace"] = 450,
		["UIDragDetectorDragStyle"] = 451,
		["UIDragDetectorResponseStyle"] = 452,
		["UIDragSpeedAxisMapping"] = 453,
		["UIFlexAlignment"] = 454,
		["UIFlexMode"] = 455,
		["UITheme"] = 456,
		["UiMessageType"] = 457,
		["UsageContext"] = 458,
		["UserCFrame"] = 459,
		["UserInputState"] = 460,
		["UserInputType"] = 461,
		["VRComfortSetting"] = 462,
		["VRControllerModelMode"] = 463,
		["VRDeviceType"] = 464,
		["VRLaserPointerMode"] = 465,
		["VRSafetyBubbleMode"] = 466,
		["VRScaling"] = 467,
		["VRSessionState"] = 468,
		["VRTouchpad"] = 469,
		["VRTouchpadMode"] = 470,
		["VelocityConstraintMode"] = 471,
		["VerticalAlignment"] = 472,
		["VerticalScrollBarPosition"] = 473,
		["VibrationMotor"] = 474,
		["VideoCaptureResult"] = 475,
		["VideoCaptureStartedResult"] = 476,
		["VideoDeviceCaptureQuality"] = 477,
		["VideoError"] = 478,
		["ViewMode"] = 479,
		["VirtualCursorMode"] = 480,
		["VirtualInputMode"] = 481,
		["VoiceChatDistanceAttenuationType"] = 482,
		["VoiceChatState"] = 483,
		["VoiceControlPath"] = 484,
		["VolumetricAudio"] = 485,
		["WaterDirection"] = 486,
		["WaterForce"] = 487,
		["WebSocketState"] = 488,
		["WeldConstraintPreserve"] = 489,
		["WhisperChatPrivacyMode"] = 490,
		["WrapLayerAutoSkin"] = 491,
		["WrapLayerDebugMode"] = 492,
		["WrapTargetDebugMode"] = 493,
		["ZIndexBehavior"] = 494,
	}
	local indexToEnum: { string } = {}
	local enumTypeByteCount: { [string]: number } = {}
	for enumName, index in enumTypeToIndex do
		local largestValue = 0
		local success, enum = pcall(function()
			return Enum[enumName]
		end)
		if success and enum then
			for _, item in enum:GetEnumItems() do
				largestValue = math.max(largestValue, item.Value)
			end
		end
		enumTypeByteCount[enumName] = if largestValue > 255 then 2 else 1
		indexToEnum[index] = enumName
	end
	
	-- The mapping of numbers to a specific enum is NOT safe for long-term storage!
	-- Size of the buffer varies 5-6 bytes depending on the largest size of the Value of the enum items.
	Sera.Enum = table.freeze({
		Name = "Enum",
		Ser = function(b: buffer, offset: number, enumItem: EnumItem): number
			if typeof(enumItem) ~= "EnumItem" then
				error(`expected EnumItem, got {typeof(enumItem)}`, 2)
			end
			if enumItem.Value > 0xFFFF then
				error(`enumItem value too large: {enumItem}`, 2)
			end
			local enumType = tostring(enumItem.EnumType)
			local enumTypeIndex = enumTypeToIndex[enumType]
			local byteCount = enumTypeByteCount[enumType]

			buffer.writeu16(b, offset, enumTypeIndex) -- first 16bit is the enum type
			offset += 2
			
			-- second is the enum value (depending on value sizes for the enum)
			if byteCount == 1 then
				buffer.writeu8(b, offset, enumItem.Value)
				offset += 1
			else
				buffer.writeu16(b, offset, enumItem.Value)
				offset += 2
			end
			return offset
		end,
		Des = function(b: buffer, offset: number): (EnumItem, number)
			local enumTypeIndex = buffer.readu16(b, offset)
			offset += 2
			local enumType: any = indexToEnum[enumTypeIndex]
			if not enumType then
				error(`invalid enum type index: {enumTypeIndex} for indexToEnum: {indexToEnum}`, 2)
			end
			local byteCount = enumTypeByteCount[enumType]
			
			local enumValue
			if byteCount == 1 then
				enumValue = buffer.readu8(b, offset)
				offset += 1
			else
				enumValue = buffer.readu16(b, offset)
				offset += 2
			end
			local enum = Enum[enumType] :: any
			local enumItem = enum:FromValue(enumValue)
			if not enumItem then
				error(`invalid enum value: {enumValue} for enum: {enumType}`, 2)
			end
			return enumItem, offset
		end,
	})
end

-- Handles buffers up to 255 bytes.
Sera.Buffer8 = table.freeze({
	Name = "Buffer8",
	Ser = function(b: buffer, offset: number, value: buffer): number
		local length = buffer.len(value)
		if length > SIZE_8 then
			error(`Buffer too long`)
		end
		buffer.writeu8(b, offset, length)
		buffer.copy(b, offset + 1, value)
		return offset + 1 + length
	end,
	Des = function(b: buffer, offset: number): (buffer, number)
		local length = buffer.readu8(b, offset)
		local value = buffer.create(length)
		buffer.copy(value, 0, b, offset + 1, length)
		return value, offset + 1 + length
	end,
})

-- Handles buffers up to 65,535 bytes.
Sera.Buffer16 = table.freeze({
	Name = "Buffer16",
	Ser = function(b: buffer, offset: number, value: buffer): number
		local length = buffer.len(value)
		if length > SIZE_16 then
			error(`Buffer too long`)
		end
		buffer.writeu16(b, offset, length)
		buffer.copy(b, offset + 2, value)
		return offset + 2 + length
	end,
	Des = function(b: buffer, offset: number): (buffer, number)
		local length = buffer.readu16(b, offset)
		local value = buffer.create(length)
		buffer.copy(value, 0, b, offset + 2, length)
		return value, offset + 2 + length
	end,
})

-- Handles buffers up to (2^32 - 1) bytes.
Sera.Buffer32 = table.freeze({
	Name = "Buffer32",
	Ser = function(b: buffer, offset: number, value: buffer): number
		local length = buffer.len(value)
		if length > SIZE_32 then
			error(`Buffer too long`)
		end
		buffer.writeu32(b, offset, length)
		buffer.copy(b, offset + 4, value)
		return offset + 4 + length
	end,
	Des = function(b: buffer, offset: number): (buffer, number)
		local length = buffer.readu32(b, offset)
		local value = buffer.create(length)
		buffer.copy(value, 0, b, offset + 4, length)
		return value, offset + 4 + length
	end,
})

-- Handles an array of up to 255 buffers, each up to 255 bytes.
Sera.BufferArray8 = table.freeze({
	Name = "BufferArray",
	Ser = function(b: buffer, offset: number, value: {buffer}): number
		local count = #value
		if count > SIZE_8 then
			error(`Array too long`)
		end
		buffer.writeu8(b, offset, count)
		offset = offset + 1
		for i = 1, count do
			local buf = value[i]
			local len = buffer.len(buf)
			if len > SIZE_8 then
				error(`Buffer element {i} too long`)
			end
			buffer.writeu8(b, offset, len)
			offset = offset + 1
			buffer.copy(b, offset, buf)
			offset = offset + len
		end
		return offset
	end,
	Des = function(b: buffer, offset: number): ({buffer}, number)
		local count = buffer.readu8(b, offset)
		offset = offset + 1
		local result = {}
		for i = 1, count do
			local len = buffer.readu8(b, offset)
			offset = offset + 1
			local buf = buffer.create(len)
			buffer.copy(buf, 0, b, offset, len)
			offset = offset + len
			table.insert(result, buf)
		end
		return result, offset
	end,
})

-- Handles an array of up to 65535 buffers, each up to 65535 bytes.
Sera.BufferArray16 = table.freeze({
	Name = "BufferArray",
	Ser = function(b: buffer, offset: number, value: {buffer}): number
		local count = #value
		if count > SIZE_16 then
			error(`Array too long`)
		end
		buffer.writeu16(b, offset, count)
		offset = offset + 2
		for i = 1, count do
			local buf = value[i]
			local len = buffer.len(buf)
			if len > SIZE_16 then
				error(`Buffer element {i} too long`)
			end
			buffer.writeu16(b, offset, len)
			offset = offset + 2
			buffer.copy(b, offset, buf)
			offset = offset + len
		end
		return offset
	end,
	Des = function(b: buffer, offset: number): ({buffer}, number)
		local count = buffer.readu16(b, offset)
		offset = offset + 2
		local result = {}
		for i = 1, count do
			local len = buffer.readu16(b, offset)
			offset = offset + 2
			local buf = buffer.create(len)
			buffer.copy(buf, 0, b, offset, len)
			offset = offset + len
			table.insert(result, buf)
		end
		return result, offset
	end,
})

do
	local rad2 = math.pi * 2
	local angle8range = math.rad(359)

	local function DegEncode(deg: number): number
		return math.round((deg % rad2) * 255 / angle8range)
	end

	local DegDecodeLookup: {number} = {}

	for i = 0, 255 do
		DegDecodeLookup[i] = i * angle8range / 255
	end

	for i = 0, 315, 45 do
		local r = math.rad(i)
		local index = DegEncode(r)
		DegDecodeLookup[index] = r
	end

	Sera.Angle8 = table.freeze({
		Name = "Angle8",
		Ser = function(b: buffer, offset: number, value: number): number
			buffer.writeu8(b, offset, DegEncode(value))
			return offset + 1
		end,
		Des = function(b: buffer, offset: number): (number, number)
			return DegDecodeLookup[buffer.readu8(b, offset)], offset + 1
		end,
	})

end

----

-- Returns dictionary of deserialized schema.
function Sera.Deserialize(schema: Schema, b: buffer, offset: number?): ({[string]: any}, number)

	offset = offset or 0
	local result = {}

	for _, field in schema.Numeric do
		result[field.Key], offset = field.Des(b, offset :: number)
	end

	return result, offset :: number

end

local function SerializeUnsafe(schema: Schema, t: {[string]: any}): number

	local offset = 0

	for _, field in schema.Numeric do
		offset = field.Ser(BB, offset, t[field.Key])
	end

	return offset

end

-- Returns new buffer of serialized schema or error message if fail.
function Sera.Serialize(schema: Schema, t: any): (buffer?, string?)

	local success, offset = pcall(SerializeUnsafe, schema, t)

	if not success then

		local ser_success
		offset = 0

		for _, field in schema.Numeric do

			local value = t[field.Key]

			if value ~= nil then
				ser_success, offset = pcall(field.Ser, BB, offset, value)
				if not ser_success then
					return nil, `Couldn't serialize field "{field.Key}" (Expected: {field.Name};Received: "{typeof(value)}"); Message: {offset}`
				end
			else
				return nil, `Missing field "{field.Key}"`
			end

		end

		return nil, `Unknown error`

	end

	local b = buffer.create(offset)
	buffer.copy(b, 0, BB, 0, offset)

	return b

end

local function PushUnsafe(schema: Schema, t: {[string]: any}, b: buffer, offset: number): number

	for _, field in schema.Numeric do
		offset = field.Ser(b, offset, t[field.Key])
	end

	return offset

end

-- Pushes serialized schema to an existing buffer; Returns new buffer offset or error message if fail.
function Sera.Push(schema: Schema, t: any, b: buffer, offset: number?): (number?, string?)

	offset = offset or 0
	local original_offset = offset :: number
	local success
	success, offset = pcall(PushUnsafe, schema, t, b, offset :: number)

	if not success then

		local ser_success
		offset = original_offset

		for _, field in schema.Numeric do

			local value = t[field.Key]

			if value ~= nil then
				ser_success, offset = pcall(field.Ser, b, offset :: number, value)
				if not ser_success then
					return nil, `Couldn't serialize field "{field.Key}" (Expected: {field.Name};Received: "{typeof(value)}"); Message: {offset}`
				end
			else
				return nil, `Missing field "{field.Key}"`
			end

		end

		return nil, `Unknown error`

	end

	return offset

end

-- Returns dictionary of deserialized deltas.
function Sera.DeltaDeserialize(schema: Schema, b: buffer, offset: number?): ({[string]: any}, number)

	offset = (offset or 0) + 1
	local field_count = buffer.readu8(b, offset :: number - 1)
	local result = {}

	local lookup = schema.Numeric

	for i = 1, field_count do
		local field = lookup[buffer.readu8(b, offset :: number)]
		result[field.Key], offset = field.Des(b, offset :: number + 1)
	end

	return result, offset :: number

end

local function DeltaSerializeUnsafe(schema: Schema, t: {[string]: any}): number

	local field_count = 0
	local offset = 1

	local lookup = schema.String

	for key, value in t do
		field_count += 1
		local field = lookup[key]
		buffer.writeu8(BB, offset, field.Index)
		offset = field.Ser(BB, offset + 1, t[field.Key])
	end

	buffer.writeu8(BB, 0, field_count)

	return offset

end

-- Returns new buffer of serialized deltas or error message if fail.
function Sera.DeltaSerialize(schema: Schema, t: any): (buffer?, string?)

	local success, offset = pcall(DeltaSerializeUnsafe, schema, t)

	if not success then

		local ser_success
		offset = 1

		local lookup = schema.String

		for key, value in t do

			local field = lookup[key]

			if field == nil then
				return nil, `Key "{key}" not specified in schema`
			end

			buffer.writeu8(BB, offset, field.Index)
			ser_success, offset = pcall(field.Ser, BB, offset + 1, value)
			if not ser_success then
				return nil, `Couldn't serialize field "{field.Key}" (Expected: {field.Name};Received: "{typeof(value)}"); Message: {offset}`
			end

		end

		return nil, `Unknown error`

	end

	local b = buffer.create(offset)
	buffer.copy(b, 0, BB, 0, offset)

	return b

end

local function DeltaPushUnsafe(schema: Schema, t: {[string]: any}, b: buffer, offset: number): number

	local field_count = 0
	local start_offset = offset
	offset += 1

	local lookup = schema.String

	for key, value in t do
		field_count += 1
		local field = lookup[key]
		buffer.writeu8(b, offset, field.Index)
		offset = field.Ser(b, offset + 1, t[field.Key])
	end

	buffer.writeu8(b, start_offset, field_count)

	return offset

end

-- Pushes serialized deltas to an existing buffer; Returns new buffer offset or error message if fail.
function Sera.DeltaPush(schema: Schema, t: any, b: buffer, offset: number?): (number?, string?)

	offset = offset or 0
	local original_offset = offset :: number
	local success
	success, offset = pcall(DeltaPushUnsafe, schema, t, b, offset :: number)

	if not success then

		local ser_success
		offset = 1

		local lookup = schema.String

		for key, value in t do

			local field = lookup[key]

			if field == nil then
				return nil, `Key "{key}" not specified in schema`
			end

			buffer.writeu8(b, offset :: number, field.Index)
			ser_success, offset = pcall(field.Ser, b, offset :: number + 1, value)
			if not ser_success then
				return nil, `Couldn't serialize field "{field.Key}" (Expected: {field.Name};Received: "{typeof(value)}"); Message: {offset}`
			end

		end

		return nil, `Unknown error`

	end

	return offset

end

function Sera.Schema(params: {[string]: SeraType}): Schema

	local fields: {Field} = {}

	for key, sera_type: SeraType in params do
		if typeof(key) ~= "string" then
			error(`[{script.Name}]: Expected string for field name; Received "{typeof(key)}"`)
		end
		if typeof(sera_type) ~= "table" or typeof(sera_type.Ser) ~= "function"
			or typeof(sera_type.Des) ~= "function" or typeof(sera_type.Name) ~= "string" then
			error(`[{script.Name}]: Expected SeraType for field "{key}"`)
		end
		table.insert(fields, {Key = key, Name = sera_type.Name, Ser = sera_type.Ser, Des = sera_type.Des, Index = 0})
	end

	if #fields == 0 then
		error(`[{script.Name}]: Schema must have fields`)
	end

	if #fields > MAX_FIELDS then
		error(`[{script.Name}]: Schema exceeded {MAX_FIELDS} fields; Received {#fields} fields`)
	end

	table.sort(fields, function(a, b)
		return a.Key < b.Key
	end)

	local string_fields: {[string]: Field} = {}

	for index, field in fields do
		field.Index = index
		string_fields[field.Key] = field
	end

	return table.freeze({
		Numeric = fields,
		String = string_fields,
	})

end

return Sera