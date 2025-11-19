--!optimize 2
--!native

return {
	Block = function(part: Part)
		local pos = part.Position
		local cf = part.CFrame
		local size = part.Size

		local s2 = size/2

		local xvec = cf.XVector.Unit * s2.X
		local yvec = cf.YVector.Unit * s2.Y
		local zvec = cf.ZVector.Unit * s2.Z

		-- Define vertices (just position calculations)
		local a = pos + xvec + yvec + zvec
		local b = pos + xvec + yvec - zvec
		local c = pos + xvec - yvec + zvec
		local d = pos + xvec - yvec - zvec
		local e = pos - xvec + yvec + zvec
		local f = pos - xvec + yvec - zvec
		local g = pos - xvec - yvec + zvec
		local h = pos - xvec - yvec - zvec

		return {a, b, c, d, e, f, g, h}
	end,
	Wedge = function(part: Part)
		local pos = part.Position
		local cf = part.CFrame
		local size = part.Size

		local s2 = size / 2

		local xvec = cf.XVector.Unit * s2.X
		local yvec = cf.YVector.Unit * s2.Y
		local zvec = cf.ZVector.Unit * s2.Z

		-- Backwards, right, up
		local a = pos + xvec + zvec + yvec
		-- Backwards, left, up
		local b = pos - xvec + zvec + yvec
		-- Backwards, right, down
		local c = pos + xvec + zvec - yvec
		-- Backwards, left, down
		local d = pos - xvec + zvec - yvec
		-- Forwards, right, down
		local e = pos + xvec - zvec - yvec
		-- Forwards, left, down
		local f = pos - xvec - zvec - yvec
		
		return {a, b, c, d, e, f}
	end,
	CornerWedge = function(part: Part)
		local pos = part.Position
		local cf = part.CFrame
		local size = part.Size

		local s2 = size / 2

		local xvec = cf.XVector.Unit * s2.X
		local yvec = cf.YVector.Unit * s2.Y
		local zvec = cf.ZVector.Unit * s2.Z
		
		-- Forwards, right, up
		local a = pos + xvec - zvec + yvec
		-- Forwards, right, down
		local b = pos + xvec - zvec - yvec
		-- Forwards, left, down
		local c = pos - xvec - zvec - yvec
		-- Backwards, right, down
		local d = pos + xvec + zvec - yvec
		-- Backwards, left, down
		local e = pos - xvec + zvec - yvec
		
		return {a, b, c, d, e}
	end,
	Cylinder = function(part: Part)
		local pos = part.Position
		local cf = part.CFrame
		local size = part.ExtentsSize

		-- Correct height and radius calculations based on the part size
		local height = size.X  -- Height is the X dimension (side-facing)
		local radius = size.Y / 2  -- Radius is half of the Y dimension

		-- Calculate the top and bottom centers based on the part's orientation
		local topCenter = pos + cf.XVector * height / 2  -- Top center is above the part by half the height
		local bottomCenter = pos - cf.XVector * height / 2  -- Bottom center is below the part by half the height

		-- Number of vertices around the circumference
		local numVertices = 8  -- You can adjust this for more/less vertices

		local vertices = {}

		-- Create top circle vertices
		for i = 0, numVertices - 1 do
			local angle = (i / numVertices) * math.pi * 2
			local x = math.cos(angle) * radius
			local z = math.sin(angle) * radius
			-- Position the top circle vertices around the XZ plane, based on the cylinder's orientation
			local topVertex = topCenter + cf.ZVector * z + cf.YVector * x
			table.insert(vertices, topVertex)
		end

		-- Create bottom circle vertices
		for i = 0, numVertices - 1 do
			local angle = (i / numVertices) * math.pi * 2
			local x = math.cos(angle) * radius
			local z = math.sin(angle) * radius
			-- Position the bottom circle vertices around the XZ plane, based on the cylinder's orientation
			local bottomVertex = bottomCenter + cf.ZVector * z + cf.YVector * x
			table.insert(vertices, bottomVertex)
		end

		return vertices
	end,
	Ball = function(part: Part)
		local pos = part.Position
		local cf = part.CFrame
		local size = part.ExtentsSize

		local radius = size.X / 2
		
		local numSlices = 8
		local numStacks = 4

		local vertices = {}
		
		for stack = 0, numStacks do
			local phi = math.pi * (stack / numStacks)
			local y = math.cos(phi) * radius
			local ringRadius = math.sin(phi) * radius

			for slice = 0, numSlices - 1 do
				local theta = 2 * math.pi * (slice / numSlices)
				local x = math.cos(theta) * ringRadius
				local z = math.sin(theta) * ringRadius
				
				local vertex = pos + cf.XVector * x + cf.YVector * y + cf.ZVector * z
				table.insert(vertices, vertex)
			end
		end

		return vertices
	end,
}