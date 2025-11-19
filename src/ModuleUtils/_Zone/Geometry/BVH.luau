--!optimize 2
--!strict
--!native

--[[
	Utility module to create a Bounding Volume Hierarchy
	from an array of boxes.
]]

local getBoundingBoxFromBoxes = require(script.Parent.Parent.SimpleZone.Utility.getBoundingBoxFromBoxes)

export type Box = {
	cframe: CFrame, 
	size: vector,
	part: BasePart?
}

export type BoxNode = {
	cframe: CFrame,
	size: vector,
	left: BoxNode?,
	right: BoxNode?,
	part: BasePart?
}

local cfget: (cf: CFrame, prop: string) -> any do
	xpcall(function()
		return (CFrame.identity::any)[""]
	end, function()
		cfget = debug.info(2, "f")
	end)
end

local function traverseBVH(root: BoxNode, callback: (box: BoxNode, stop: () -> ()) -> boolean)
	local stack = {root}
	local stackSize = 1
	local stopFlag = false

	local function stop()
		table.clear(stack)
		stopFlag = true
	end
	
	while stackSize > 0 do
		local node = table.remove(stack)
		if not node then break end
		stackSize -= 1
		
		local shouldContinue = callback(node, stop)
		if not shouldContinue then continue	end
		if stopFlag then break end

		if node.right then
			stackSize += 1
			stack[stackSize] = node.right
		end
		
		if node.left then
			stackSize += 1
			stack[stackSize] = node.left
		end
	end
end

local function determine(parent: BoxNode, name: string, boxes: {Box})
	if #boxes > 1 then
		local cframe, size = getBoundingBoxFromBoxes(boxes)
		parent[name] = {
			cframe = cframe,
			size = size,
			--volume = size.x * size.y * size.z
		}

		split(parent[name], boxes)
	elseif #boxes == 1 then
		local box = boxes[1]
		parent[name] = {
			cframe = box.cframe,
			size = box.size,
			--volume = box.size.x * box.size.y * box.size.z,
			part = box.part,
		}
	end
end

function split(parent: BoxNode, boxes: {Box})
	local size = parent.size
	local longestAxis

	if size.x >= size.y and size.x >= size.z then
		longestAxis = "X"
	elseif size.y >= size.x and size.y >= size.z then
		longestAxis = "Y"
	elseif size.z >= size.y and size.z >= size.x then
		longestAxis = "Z"
	end
	
	table.sort(boxes, function(a, b)
		return cfget(a.cframe, longestAxis) < cfget(b.cframe, longestAxis)
	end)

	local len = #boxes
	local mid = len//2

	local leftBoxes = table.create(mid)
	local rightBoxes = table.create(mid)
	table.move(boxes, 1, mid, 1, leftBoxes)
	table.move(boxes, mid + 1, len, 1, rightBoxes)

	determine(parent, "left", leftBoxes)
	determine(parent, "right", rightBoxes)
end

local function createBVH(boxes: {Box}): (BoxNode)
	if #boxes == 0 then
		return {
			cframe = CFrame.new(0, 0, 0),
			size = vector.create(0, 0, 0)
		}
	end

	local cframe, size = getBoundingBoxFromBoxes(boxes)

	local root = {
		cframe = cframe,
		size = size
	}

	split(root, boxes)

	return root
end

local function needsUpdate(oldBox: Box, newBox: Box, threshold: number)
	-- Check if the box has moved significantly
	local distance = vector.magnitude((oldBox.cframe.Position - newBox.cframe.Position)::any)
	local sizeChange = vector.magnitude(oldBox.size - newBox.size)

	-- Update if position changed more than threshold or size changed significantly
	return distance > threshold or sizeChange > threshold
end

local function updateBVHNode(node: BoxNode?, oldBoxes: {Box}, newBoxes: {Box}, threshold: number)
	if not node then return false end
	
	-- Leaf node
	if node.part then
		local oldBox = {
			cframe = node.cframe,
			size = node.size,
			--volume = node.volume,
			part = node.part
		}

		-- Find corresponding new box
		local newBox
		for _, box in newBoxes do
			if box.part == node.part then
				newBox = box
				break
			end
		end

		-- If part found and needs update
		if newBox and needsUpdate(oldBox, newBox, threshold) then
			node.cframe = newBox.cframe
			node.size = newBox.size
			--node.volume = newBox.volume
			return true
		end
		return false
	end

	-- Internal node
	local leftUpdated = updateBVHNode(node.left, oldBoxes, newBoxes, threshold)
	local rightUpdated = updateBVHNode(node.right, oldBoxes, newBoxes, threshold)

	-- If either child updated, recalculate bounds
	if leftUpdated or rightUpdated then
		-- Get combined bounds of children
		local leftBounds = node.left and {
			cframe = node.left.cframe,
			size = node.left.size,
			--volume = node.left.volume
		}
		local rightBounds = node.right and {
			cframe = node.right.cframe,
			size = node.right.size,
			--volume = node.right.volume
		}

		if leftBounds and rightBounds then
			local leftPos: vector = leftBounds.cframe.Position :: any
			local rightPos: vector = rightBounds.cframe.Position :: any
			
			local minBounds = vector.create(
				math.min(leftPos.x - leftBounds.size.x/2, rightPos.x - rightBounds.size.x/2),
				math.min(leftPos.y - leftBounds.size.y/2, rightPos.y - rightBounds.size.y/2),
				math.min(leftPos.z - leftBounds.size.z/2, rightPos.z - rightBounds.size.z/2)
			)

			local maxBounds = vector.create(
				math.max(leftPos.x + leftBounds.size.x/2, rightPos.x + rightBounds.size.x/2),
				math.max(leftPos.y + leftBounds.size.y/2, rightPos.y + rightBounds.size.y/2),
				math.max(leftPos.z + leftBounds.size.z/2, rightPos.z + rightBounds.size.z/2)
			)
			local size = maxBounds - minBounds
			local center = (minBounds + maxBounds) / 2

			node.cframe = CFrame.new(center::any)
			node.size = size
			--node.volume = size.x * size.y * size.z
		elseif leftBounds then
			node.cframe = leftBounds.cframe
			node.size = leftBounds.size
			--node.volume = leftBounds.volume
		elseif rightBounds then
			node.cframe = rightBounds.cframe
			node.size = rightBounds.size
			--node.volume = rightBounds.volume
		end

		return true
	end

	return false
end

local function updateBVH(bvh: BoxNode, oldBoxes: {Box}, newBoxes: {Box}, threshold: number?)
	local threshold = threshold or 0.1
	
	if bvh.size == vector.zero and #newBoxes > 0 then
		local newBVH = createBVH(newBoxes)
		bvh.cframe = newBVH.cframe
		bvh.size = newBVH.size
		bvh.left = newBVH.left
		bvh.right = newBVH.right

		return true, bvh
	end
	
	local success = updateBVHNode(bvh, oldBoxes, newBoxes, threshold)
	return success, bvh
end

local function visualize(bvh)
	traverseBVH(bvh, function(box)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Transparency = 0.9
		part.CastShadow = false
		part.CFrame = box.cframe
		part.Size = box.size::any
		part.Parent = workspace

		part.CanCollide = false
		part.CanQuery = false

		if not box.right and not box.left then
			part.Color = Color3.fromRGB(255, 0, 0)
		end

		return true
	end)
end

return {
	createBVH = createBVH,
	traverseBVH = traverseBVH,
	updateBVH = updateBVH,
	visualize = visualize,
}