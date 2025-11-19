--!strict
--@author: crusherfire
--@date: 12/21/24
--[[@description:
	Extra utility functions for buffers for working with Roblox Data Types
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local Sera = require("./_Sera")
local t = require("./_t")

-----------------------------
-- TYPES --
-----------------------------

type ReceiptInfo = {
	PurchaseId: number,
	PlayerId: number,
	ProductId: number,
	PlaceIdWherePurchased: number,
	CurrencySpent: number,
	CurrencyType: Enum.CurrencyType,
	ProductPurchaseChannel: Enum.ProductPurchaseChannel
}

-----------------------------
-- VARIABLES --
-----------------------------
local Module = {}

local raycastParamsSchema = Sera.Schema({
	FilterTypeEnumId = Sera.Int8,
	IgnoreWater = Sera.Boolean,
	CollisionGroup = Sera.String16,
	RespectCanCollide = Sera.Boolean,
	BruteForceAllSlow = Sera.Boolean
})

local raycastResultSchema = Sera.Schema({
	Position = Sera.Vector3,
	Normal = Sera.Vector3,
	MaterialEnumId = Sera.Int8,
	Distance = Sera.Float32
})

local receiptInfoSchema = Sera.Schema({
	PurchaseId = Sera.String8,
	PlayerId = Sera.Float64,
	ProductId = Sera.Float64,
	PlaceIdWherePurchased = Sera.Float64,
	CurrencySpent = Sera.Uint16,
	CurrencyType = Sera.Enum,
	ProductPurchaseChannel = Sera.Enum
})

local TAU = math.pi * 2
local VECTOR_ONES = Vector3.new(1, 1, 1)

local NORMAL_ID_VECTORS = { -- [Enum.Value] = Vector3.fromNormalId(Enum)
	[0] = Vector3.new(1, 0, 0), -- Enum.NormalId.Right
	[1] = Vector3.new(0, 1, 0), -- Enum.NormalId.Top
	[2] = Vector3.new(0, 0, 1), -- Enum.NormalId.Back
	[3] = Vector3.new(-1, 0, 0), -- Enum.NormalId.Left
	[4] = Vector3.new(0, -1, 0), -- Enum.NormalId.Bottom
	[5] = Vector3.new(0, 0, -1) -- Enum.NormalId.Front
}

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

--[[
	Encodes the yaw into into an 16-bit unsigned integer [0, 65535].
]]
function Module.encodeYawToUint16(yawInRadians: number): number
	yawInRadians = yawInRadians % TAU
	return math.floor((yawInRadians / TAU) * 65_535) % 65_535
end

--[[
	Decodes a 16-bit unsigned yaw rotation [0, 65535] back into radians [0, 2pi].
]]
function Module.decodeUint16ToYaw(encoded: number): number
	return (encoded / 65_535) * TAU
end

-- Serializes a raycast result for use in remote events.
function Module.serializeRaycastResult(result: RaycastResult): (boolean, any)
	local b, err = Sera.Serialize(raycastResultSchema, {
		Position = result.Position,
		Normal = result.Normal,
		MaterialEnumId = result.Material.Value,
		Distance = result.Distance
	})
	if err then
		return false, err
	end
	return true, { b :: any, result.Instance }
end

function Module.deserializeRaycastResult(serialized: any): (boolean, string | RaycastResult)
	if not t.table(serialized) then
		return false, "invalid table"
	end
	if not t.buffer(serialized[1]) then
		return false, "invalid buffer"
	end
	if not t.Instance(serialized[2]) then
		return false, "invalid instance"
	end
	local data = Sera.Deserialize(raycastResultSchema, serialized[1])
	return true, {
		Position = data.Position,
		Material = Enum.Material:FromValue(data.MaterialEnumId) :: any,
		Normal = data.Normal,
		Distance = data.Distance,
		Instance = serialized[2]
	} :: RaycastResult
end

-- Serializes a raycast param for use in remote events.
-- CollisionGroup must be no longer than 16 characters long.
function Module.serializeRaycastParams(params: RaycastParams): (boolean, any)
	if params.CollisionGroup:len() > 16 then
		return false, "CollisionGroup name too long"
	end
	local b, err = Sera.Serialize(raycastParamsSchema, {
		FilterTypeEnumId = params.FilterType.Value,
		IgnoreWater = params.IgnoreWater,
		CollisionGroup = params.CollisionGroup,
		RespectCanCollide = params.RespectCanCollide,
		BruteForceAllSlow = params.BruteForceAllSlow
	})
	if err then
		return false, err
	end
	return true, { b :: any, params.FilterDescendantsInstances }
end

function Module.deserializeRaycastParams(serialized: any): (boolean, string | RaycastParams)
	if not t.table(serialized) then
		return false, "invalid table"
	end
	if not t.buffer(serialized[1]) then
		return false, "invalid buffer"
	end
	if not t.array(t.Instance)(serialized[2]) then
		return false, "invalid FilterDescendantInstances"
	end
	local data = Sera.Deserialize(raycastParamsSchema, serialized[1])
	local params = RaycastParams.new()
	params.FilterDescendantsInstances = serialized[2]
	params.FilterType = Enum.RaycastFilterType:FromValue(data.FilterTypeEnumId) :: any
	params.CollisionGroup = data.CollisionGroup
	params.IgnoreWater = data.IgnoreWater
	params.RespectCanCollide = data.RespectCanCollide
	params.BruteForceAllSlow = data.BruteForceAllSlow
	return true, params
end

function Module.fromReceiptInfo(info: ReceiptInfo): buffer
	local b, err = Sera.Serialize(receiptInfoSchema, {
		PurchaseId = info.PurchaseId,
		PlayerId = info.PlayerId,
		ProductId = info.ProductId,
		PlaceIdWherePurchased = info.PlaceIdWherePurchased,
		CurrencySpent = info.CurrencySpent,
		CurrencyType = info.CurrencyType,
		ProductPurchaseChannel = info.ProductPurchaseChannel,
	})
	if err then
		error(err, 2)
	end
	return b :: buffer
end

function Module.toReceiptInfo(b: buffer): ReceiptInfo
	local info = Sera.Deserialize(receiptInfoSchema, b)
	return info
end

-- Creates a buffer with a terminated string (strings of bytes that end in a 0 byte). This allows you to easily know when a string ends in a buffer.
-- <strong>extraOffset</strong>: Increases buffer byte size if needing to store extra data in the buffer. Default size is length of the string.
-- Returns the buffer & total length of the buffer.
function Module.writeTerminatedString(str: string, extraOffset: number?): (buffer, number)
	local strLength = #str
	local padding = extraOffset or 0
	local bufferLength = strLength + 1 + padding
	local b = buffer.create(bufferLength) -- +1 for the 0 byte
	for i = 1, strLength do
		buffer.writeu8(b, i - 1, string.byte(str, i, i))
	end
	buffer.writeu8(b, strLength + 1, 0)
	return b, bufferLength
end

-- Reads the buffer and builds a string. Reading stops if a null-character is reached or the buffer ends.
function Module.readTerminatedString(b: buffer): (string)
	local outputCharacters = {}
	local maxLength = buffer.len(b)
	local length = 0
	-- Bytes are read continuously until a null-character is reached or until the buffer ends.
	while true do
		local byte = buffer.readu8(b, length)
		if length == maxLength then
			-- End of buffer reached
			break
		elseif byte == 0 then
			-- String has ended
			break
		else
			length += 1
			outputCharacters[length] = byte
		end
	end
	
	return string.char(table.unpack(outputCharacters))
end

-- Stores the BrickColor to a buffer as a 16-bit unsigned integer.
function Module.fromBrickColor(c: BrickColor): buffer
	local b = buffer.create(2)
	buffer.writeu16(b, 0, c.Number)
	return b
end

function Module.toBrickColor(b: buffer): BrickColor
	return BrickColor.new(buffer.readu16(b, 0))
end

-- Stores the Color3 to a buffer as a 24-bit integer.
-- R, G, B values are expected to be whole integers.
function Module.fromColor3(c: Color3): buffer
	local b = buffer.create(3)
	buffer.writeu8(b, 0, math.clamp(math.round(c.R * 255), 0, 255))
	buffer.writeu8(b, 1, math.clamp(math.round(c.G * 255), 0, 255))
	buffer.writeu8(b, 2, math.clamp(math.round(c.B * 255), 0, 255))
	return b
end

function Module.toColor3(b: buffer): Color3
	return Color3.fromRGB(buffer.readu8(b, 0), buffer.readu8(b, 1), buffer.readu8(b, 2))
end

-- Stores the Vector3 in a buffer with three 32-bit floats (12 bytes).
function Module.fromVector3(v: Vector3): buffer
	local b = buffer.create(12)
	buffer.writef32(b, 0, v.X)
	buffer.writef32(b, 4, v.Y)
	buffer.writef32(b, 8, v.Z)
	return b
end

-- <strong>offset</strong> Optional starting point to read values from the buffer. Default is 0.
function Module.toVector3(b: buffer, offset: number?): Vector3
	local offset = offset or 0
	return Vector3.new(buffer.readf32(b, 0 + offset), buffer.readf32(b, 4 + offset), buffer.readf32(b, 8 + offset))
end

-- Stores the Vector2 in a buffer with two 32-bit floats (8 bytes).
function Module.fromVector2(v: Vector2): buffer
	local b = buffer.create(8)
	buffer.writef32(b, 0, v.X)
	buffer.writef32(b, 4, v.Y)
	return b
end

function Module.toVector2(b: buffer): Vector2
	return Vector2.new(buffer.readf32(b, 0), buffer.readf32(b, 4))
end

-- Stores the UDim2 in a buffer with two 32-bit floats and two signed 32-bit integers (16 bytes total).
function Module.fromUDim2(u: UDim2): buffer
	local b = buffer.create(16)
	buffer.writef32(b, 0, u.X.Scale)
	buffer.writei32(b, 4, u.X.Offset)
	buffer.writef32(b, 8, u.Y.Scale)
	buffer.writei32(b, 12, u.Y.Offset)
	return b
end

function Module.toUDim2(b: buffer): UDim2
	return UDim2.new(buffer.readf32(b, 0), buffer.readi32(b, 4), buffer.readf32(b, 8), buffer.readi32(b, 12))
end

-- Stores the ray as two Vector2's representing Origin and Direction (24 bytes total).
function Module.fromRay(r: Ray)
	local b = buffer.create(24)
	local origin = Module.fromVector3(r.Origin)
	local direction = Module.fromVector3(r.Direction)
	buffer.copy(b, 0, origin, 0)
	buffer.copy(b, 12, direction, 0)
	return b
end

function Module.toRay(b: buffer): Ray
	local origin = Module.toVector3(b)
	local direction = Module.toVector3(b, 12)
	return Ray.new(origin, direction)
end

-- Stores the CFrame to a buffer. If the CFrame is axis aligned, it takes up 13 bytes. Otherwise, it takes 49 bytes.
function Module.fromCFrame(cf: CFrame): buffer
	local upVector = cf.UpVector
	local rightVector = cf.RightVector
	
	-- Source for how to store CFrame in a buffer:
	-- https://github.com/Dekkonot/bitbuffer/blob/main/src/roblox.lua
	
	-- This is an easy trick to check if a CFrame is axis-aligned:
	-- Essentially, in order for a vector to be axis-aligned, two of the components have to be 0
	-- This means that the dot product between the vector and a vector of all 1s will be 1 (0*x = 0)
	-- Since these are all unit vectors, there is no other combination that results in 1.
	local rightAligned = math.abs(rightVector:Dot(VECTOR_ONES))
	local upAligned = math.abs(upVector:Dot(VECTOR_ONES))
	
	local axisAligned = (math.abs(1 - rightAligned) < 0.00001 or rightAligned == 0)
		and (math.abs(1 - upAligned) < 0.00001 or upAligned == 0)
	
	if axisAligned then
		local position = cf.Position
		-- The ID of an orientation is generated through what can best be described as 'hand waving';
		-- This is how Roblox does it and it works, so it was chosen to do it this way too.
		local rightNormal, upNormal
		for i = 0, 5 do
			local v = NORMAL_ID_VECTORS[i]
			if 1 - v:Dot(rightVector) < 0.00001 then
				rightNormal = i
			end
			if 1 - v:Dot(upVector) < 0.00001 then
				upNormal = i
			end
		end
		-- The ID generated here is technically off by 1 from what Roblox would store, but that's not important
		-- It just means that 0x02 is actually 0x01 for the purposes of this module's implementation.
		
		local b = buffer.create(13)
		buffer.writeu8(b, 0, rightNormal * 6 + upNormal) -- Indicates this CFrame is axis-aligned.
		buffer.writef32(b, 1, position.X)
		buffer.writef32(b, 5, position.Y)
		buffer.writef32(b, 9, position.Z)
		return b
	else
		local b = buffer.create(49)
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		buffer.writeu8(b, 0, 0) -- Indicates this CFrame is not axis-aligned.
		buffer.writef32(b, 1, x)
		buffer.writef32(b, 5, y)
		buffer.writef32(b, 9, z)
		buffer.writef32(b, 13, r00)
		buffer.writef32(b, 17, r01)
		buffer.writef32(b, 21, r02)
		buffer.writef32(b, 25, r10)
		buffer.writef32(b, 29, r11)
		buffer.writef32(b, 33, r12)
		buffer.writef32(b, 37, r20)
		buffer.writef32(b, 41, r21)
		buffer.writef32(b, 45, r22)
		return b
	end
end

function Module.toCFrame(b: buffer): CFrame
	local id = buffer.readu8(b, 0)
	
	if id == 0 then
		-- this is not an axis-aligned CFrame
		return CFrame.new(
			buffer.readf32(b, 1), buffer.readf32(b, 5), buffer.readf32(b, 9),
			buffer.readf32(b, 13), buffer.readf32(b, 17), buffer.readf32(b, 21),
			buffer.readf32(b, 25), buffer.readf32(b, 29), buffer.readf32(b, 33),
			buffer.readf32(b, 37), buffer.readf32(b, 41), buffer.readf32(b, 45)
		)
	else
		local rightVector = NORMAL_ID_VECTORS[math.floor(id / 6)]
		local upVector = NORMAL_ID_VECTORS[id % 6]
		local lookVector = rightVector:Cross(upVector)
		
		return CFrame.new(
			buffer.readf32(b, 1), buffer.readf32(b, 5), buffer.readf32(b, 9),
			rightVector.X, upVector.X, lookVector.X,
			rightVector.Y, upVector.Y, lookVector.Y,
			rightVector.Z, upVector.Z, lookVector.Z
		)
	end
end

-- Buffer size varies due to the nature of this data type. Each value of a keypoint is stored as a 32-bit float.
function Module.fromNumberSequence(s: NumberSequence): buffer
	local numOfKeypoints = #s.Keypoints
	local bufferSize = numOfKeypoints * 3 * 4 -- 3 values per keypoint, 4 bytes for each value
	local b = buffer.create(bufferSize + 4) -- extra 4 bytes to indicate num of keypoints
	
	buffer.writeu32(b, 0, numOfKeypoints)
	local offset = 4
	for _, keypoint in ipairs(s.Keypoints) do
		buffer.writef32(b, offset, keypoint.Time)
		offset += 4
		buffer.writef32(b, offset, keypoint.Value)
		offset += 4
		buffer.writef32(b, offset, keypoint.Envelope)
		offset += 4
	end
	return b
end

function Module.toNumberSequence(b: buffer): NumberSequence
	local keypointCount = buffer.readu32(b, 0)
	local keypoints = table.create(keypointCount)
	
	-- As it turns out, creating a NumberSequence with a negative value as its first argument (in the first and second constructor)
	-- creates NumberSequenceKeypoints with negative envelopes. The envelope is read and saved properly, as you would expect,
	-- but you can't create a NumberSequence with a negative envelope if you're using a table of keypoints (which is happening here).
	-- If you're confused, run this snippet: NumberSequence.new(NumberSequence.new(-1).Keypoints)
	-- As a result, there has to be some branching logic in this function.
	-- ColorSequences don't have envelopes so it's not necessary for them.
	
	local offset = 4
	for i = 1, keypointCount do
		local time = buffer.readf32(b, offset)
		offset += 4
		local value = buffer.readf32(b, offset)
		offset += 4
		local envelope: number? = buffer.readf32(b, offset)
		if value < 0 then
			envelope = nil
		end
		offset += 4
		keypoints[i] = NumberSequenceKeypoint.new(time, value, envelope)
	end
	
	return NumberSequence.new(keypoints)
end

-- Stores the number range in a buffer with two 32-bit floats for the Min and Max (8 bytes total).
-- If the min and max is the same, then the buffer is 4 bytes.
function Module.fromNumberRange(r: NumberRange): buffer
	if r.Min ~= r.Max then
		local b = buffer.create(8)
		buffer.writef32(b, 0, r.Min)
		buffer.writef32(b, 4, r.Max)
		return b
	else
		local b = buffer.create(4)
		buffer.writef32(b, 0, r.Min)
		return b
	end
end

function Module.toNumberRange(b: buffer): NumberRange
	if buffer.len(b) == 4 then
		local num = buffer.readf32(b, 0)
		return NumberRange.new(num)
	else
		return NumberRange.new(buffer.readf32(b, 0), buffer.readf32(b, 4))
	end
end

-- Stores the number as a 32-bit float.
function Module.fromFloat(num: number): buffer
	local b = buffer.create(4)
	buffer.writef32(b, 0, num)
	return b
end

function Module.toFloat(b: buffer): number
	return buffer.readf32(b, 0)
end

-- Given an integer, this function will store the number in the buffer with the smallest possible size.
-- Floats passed to this function will lose all precision.
-- Accepts numbers below 0.
-- You can optionally specify the size in bytes instead (1, 2, 4, or 8)
function Module.fromSigned(num: number, bytes: number?): buffer
	if bytes and not t.literal(1, 2, 4, 8)(bytes) then
		error("Invalid byte size", 2)
	end
	local b: buffer

	if bytes == 1 or (not bytes and num >= -128 and num <= 127) then -- 8 bit
		b = buffer.create(bytes or 1)
		buffer.writei8(b, 0, num)
	elseif bytes == 2 or (num >= -32768 and num <= 32767) then -- 16 bit
		b = buffer.create(bytes or 2)
		buffer.writei16(b, 0, num)
	elseif bytes == 4 or (not bytes and num >= -2147483648 and num <= 2147483647) then -- 32 bit
		b = buffer.create(bytes or 4)
		buffer.writei32(b, 0, num)
	else
		b = buffer.create(bytes or 8) -- 64 bit
		buffer.writef64(b, 0, num)
	end
	
	return b
end

-- Returns the integer stored in the buffer returned by .fromUnsigned()
function Module.toSigned(b: buffer): number
	local len = buffer.len(b)
	
	if len == 1 then
		return buffer.readi8(b, 0)
	elseif len == 2 then
		return buffer.readi16(b, 0)
	elseif len == 4 then
		return buffer.readi32(b, 0)
	else
		return buffer.readf64(b, 0)
	end
end

-- Given an integer, this function will store the number in the buffer with the smallest possible size.
-- Floats passed to this function will lose all precision.
-- Do not pass any numbers below 0.
-- You can optionally specify the size in bytes instead (1, 2, 4, or 8)
function Module.fromUnsigned(num: number, bytes: number?): buffer
	assert(num >= 0, "Received signed integer!")
	if bytes and not t.literal(1, 2, 4, 8)(bytes) then
		error("Invalid byte size", 2)
	end
	local b: buffer
	
	if bytes == 1 or (not bytes and num <= 0xFF) then -- 8 bit
		b = buffer.create(1)
		buffer.writeu8(b, 0, num)
	elseif bytes == 2 or (not bytes and num <= 0xFFFF) then -- 16 bit
		b = buffer.create(2)
		buffer.writeu16(b, 0, num)
	elseif bytes == 4 or (not bytes and num <= 0xFFFFFFFF) then -- 32 bit
		b = buffer.create(4)
		buffer.writeu32(b, 0, num)
	else
		b = buffer.create(8) -- 64 bit
		buffer.writef64(b, 0, num)
	end
	
	return b
end

-- Returns the integer stored in the buffer returned by .fromUnsigned()
function Module.toUnsigned(b: buffer): number
	local len = buffer.len(b)
	if len == 1 then
		return buffer.readu8(b, 0)
	elseif len == 2 then
		return buffer.readu16(b, 0)
	elseif len == 4 then
		return buffer.readu32(b, 0)
	else
		return buffer.readf64(b, 0)
	end
end

-- Buffer size varies due to the nature of this data type.
function Module.fromEnum(e: EnumItem): buffer
	local b, bufferLength = Module.writeTerminatedString(tostring(e.EnumType), 2)
	buffer.writeu16(b, bufferLength - 2, e.Value) -- Assuming enum IDs never go beyond 16-bit unsigned integers
	return b
end

function Module.toEnum(b: buffer)
	local name = Module.readTerminatedString(b)
	local value = buffer.readu16(b, buffer.len(b) - 2) -- Assuming enum IDs never go beyond 16-bit unsigned integers

	for _, v in ipairs(Enum[name]:GetEnumItems()) do
		if v.Value == value then
			return v
		end
	end
	
	error(`toEnum() could not get value!\n{value} is not a valid member of {name}`, 2)
end

-----------------------------
-- MAIN --
-----------------------------
return Module