--!strict
--!native
-- created by bhristt (october 15 2021)
-- bezier module for easy creation of bezier curves
-- updated (october 25 2021)
-- strict mode & types updated by crusherfire (4/17/25)
-- Vector2 support added by ChatGPT (6/25/2025)

-- types
export type BezierPoint = {
	Type: "StaticPoint" | "BasePartPoint";
	Point: Vector3 | Vector2 | BasePart;
}

local Bezier = {}
Bezier.__index = Bezier

type fields = {
	Points: { BezierPoint },
	LengthIterations: number,
	LengthIndeces: any,
	Length: number,
	_connections: { [BasePart]: { RBXScriptConnection } }
}
export type BezierCurve = typeof(setmetatable({} :: fields, Bezier))

-- factorial helper for Bernstein
local function fact(n: number): number
	if n == 0 then
		return 1
	else
		return n * fact(n - 1)
	end
end

-- Bernstein polynomial
local function B(n: number, i: number, t: number): number
	return (fact(n) / (fact(i) * fact(n - i))) * t^i * (1 - t)^(n - i)
end

--[[
	Creates a new Bezier curve.
]]
function Bezier.new(...: (Vector3 | Vector2 | BasePart)): BezierCurve
	local self = setmetatable({}, Bezier)
	self.Points = {}
	self.LengthIterations = 1000
	self.LengthIndeces = {}
	self.Length = 0
	self._connections = {}

	for _, p in pairs({...}) do
		if typeof(p) == "Vector3" or typeof(p) == "Vector2"
			or (typeof(p) == "Instance" and p:IsA("BasePart")) then
			self:AddBezierPoint(p)
		else
			error("Bezier.new() only accepts Vector3, Vector2, or BasePart")
		end
	end

	return self
end

-- add a control point
function Bezier.AddBezierPoint(self: BezierCurve, p: Vector3 | Vector2 | BasePart, index: number?)
	-- validate
	if not (typeof(p) == "Vector3" or typeof(p) == "Vector2"
		or (typeof(p) == "Instance" and p:IsA("BasePart"))) then
		error("Bezier:AddBezierPoint() only accepts Vector3, Vector2, or BasePart")
	end

	local newPoint: BezierPoint = {
		Type = ((typeof(p) == "Instance") and "BasePartPoint" or "StaticPoint") :: any;
		Point = p;
	}

	-- if it's a BasePart, listen for moves/removal
	if newPoint.Type == "BasePartPoint" then
		local part = p :: BasePart
		local connChanged = part.Changed:Connect(function(prop)
			if prop == "Position" then
				self:UpdateLength()
			end
		end)
		local connRemoved
		connRemoved = part.AncestryChanged:Connect(function(_, parent)
			if not parent then
				local idx = table.find(self.Points, newPoint)
				if idx then
					table.remove(self.Points, idx)
				end
				connChanged:Disconnect()
				connRemoved:Disconnect()
			end
		end)
		self._connections[part] = self._connections[part] or {}
		table.insert(self._connections[part], connChanged)
		table.insert(self._connections[part], connRemoved)
	end

	-- insert at index or append
	if index then
		if type(index) ~= "number" then
			error("Bezier:AddBezierPoint() index must be a number")
		end
		table.insert(self.Points, index, newPoint)
	else
		table.insert(self.Points, newPoint)
	end

	self:UpdateLength()
end

-- change an existing control point
function Bezier.ChangeBezierPoint(self: BezierCurve, index: number, p: Vector3 | Vector2 | BasePart)
	if type(index) ~= "number" then
		error("Bezier:ChangeBezierPoint() index must be a number")
	end
	if not (typeof(p) == "Vector3" or typeof(p) == "Vector2"
		or (typeof(p) == "Instance" and p:IsA("BasePart"))) then
		error("Bezier:ChangeBezierPoint() only accepts Vector3, Vector2, or BasePart")
	end

	local entry = self.Points[index]
	if not entry then
		error("Bezier:ChangeBezierPoint() no point at index " .. index)
	end

	-- disconnect old BasePart if needed
	if entry.Type == "BasePartPoint" then
		local oldPart = entry.Point :: BasePart
		for _, conn in ipairs(self._connections[oldPart] or {}) do
			if conn.Connected then
				conn:Disconnect()
			end
		end
		self._connections[oldPart] = nil
	end

	-- assign new
	entry.Type = ((typeof(p) == "Instance") and "BasePartPoint" or "StaticPoint") :: any
	entry.Point = p

	-- hook up new BasePart if needed
	if entry.Type == "BasePartPoint" then
		local part = p :: BasePart
		local connChanged = part.Changed:Connect(function(prop)
			if prop == "Position" then
				self:UpdateLength()
			end
		end)
		local connRemoved
		connRemoved = part.AncestryChanged:Connect(function(_, parent)
			if not parent then
				local idx = table.find(self.Points, entry)
				if idx then
					table.remove(self.Points, idx)
				end
				connChanged:Disconnect()
				connRemoved:Disconnect()
			end
		end)
		self._connections[part] = { connChanged, connRemoved }
	end

	self:UpdateLength()
end

-- retrieve the raw Vector2/Vector3 of a control
function Bezier.GetPoint(self: BezierCurve, i: number): Vector3 | Vector2
	local entry = self.Points[i]
	if not entry then
		error("Bezier:GetPoint() no point at index " .. i)
	end
	if typeof(entry.Point) == "Instance" then
		return (entry.Point :: BasePart).Position
	else
		return entry.Point
	end
end

-- get all controls as a homogeneous array
function Bezier.GetAllPoints(self: BezierCurve): { Vector3 | Vector2 }
	local out = {}
	for i = 1, #self.Points do
		out[i] = self:GetPoint(i)
	end
	return out
end

-- recalc cached length
function Bezier.UpdateLength(self: BezierCurve)
	local pts = self:GetAllPoints()
	if #pts < 2 then
		self.Length = 0
		self.LengthIndeces = {}
		return 0, {}
	end

	local total = 0
	local sums: { any } = {}
	local iters = self.LengthIterations

	for i = 1, iters do
		local t = (i - 1) / (iters - 1)
		local deriv: any = self:CalculateDerivativeAt(t)
		total += deriv.Magnitude * (1 / iters)
		sums[i] = { t, total, deriv }
	end

	self.Length = total
	self.LengthIndeces = sums
	return total, sums
end

-- compute position at parameter t∈[0,1]
function Bezier.CalculatePositionAt(self: BezierCurve, t: number): Vector3 | Vector2
	if type(t) ~= "number" then
		error("Bezier:CalculatePositionAt() requires a number")
	end
	local points = self:GetAllPoints()
	if #points == 0 then
		error("Bezier:CalculatePositionAt() needs at least 1 point")
	end

	local is2D = typeof(points[1]) == "Vector2"
	local c_t = if is2D then Vector2.new() else Vector3.new()

	local n = #points - 1
	for i, p: any in ipairs(points) do
		c_t += B(n, i - 1, t) * p
	end

	return c_t
end

-- compute derivative at t∈[0,1]
function Bezier.CalculateDerivativeAt(self: BezierCurve, t: number): Vector3 | Vector2
	if type(t) ~= "number" then
		error("Bezier:CalculateDerivativeAt() requires a number")
	end
	local points = self:GetAllPoints()
	if #points < 2 then
		error("Bezier:CalculateDerivativeAt() needs at least 2 points")
	end

	local is2D = typeof(points[1]) == "Vector2"
	local prime = if is2D then Vector2.new() else Vector3.new()

	local n = #points
	for i = 1, n - 1 do
		local p0: any, p1: any = points[i], points[i + 1]
		local Q = (n - 1) * (p1 - p0)
		prime += B(n - 2, i - 1, t) * Q
	end

	return prime
end

return Bezier