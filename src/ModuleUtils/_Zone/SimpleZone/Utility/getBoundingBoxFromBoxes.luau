local function getBoundingBoxFromBoxes(boxes)
	local minBounds = vector.create(math.huge, math.huge, math.huge)
	local maxBounds = vector.create(-math.huge, -math.huge, -math.huge)

	for _, box in boxes do
		local cframe, size = box.cframe, box.size
		local halfSize = size * 0.5
		local corners = {
			cframe.Position + vector.create(-halfSize.x, -halfSize.y, -halfSize.z),
			cframe.Position + vector.create(halfSize.x, -halfSize.y, -halfSize.z),
			cframe.Position + vector.create(-halfSize.x, halfSize.y, -halfSize.z),
			cframe.Position + vector.create(halfSize.x, halfSize.y, -halfSize.z),
			cframe.Position + vector.create(-halfSize.x, -halfSize.y, halfSize.z),
			cframe.Position + vector.create(halfSize.x, -halfSize.y, halfSize.z),
			cframe.Position + vector.create(-halfSize.x, halfSize.y, halfSize.z),
			cframe.Position + vector.create(halfSize.x, halfSize.y, halfSize.z),
		}

		for _, corner in corners do
			minBounds = vector.create(
				math.min(minBounds.x, corner.x),
				math.min(minBounds.y, corner.y),
				math.min(minBounds.z, corner.z)
			)
			maxBounds = vector.create(
				math.max(maxBounds.x, corner.x),
				math.max(maxBounds.y, corner.y),
				math.max(maxBounds.z, corner.z)
			)
		end
	end
	local size = maxBounds - minBounds
	local center = (minBounds + maxBounds) / 2
	local boundingCFrame = CFrame.new(center::any)

	return boundingCFrame, size
end

return getBoundingBoxFromBoxes