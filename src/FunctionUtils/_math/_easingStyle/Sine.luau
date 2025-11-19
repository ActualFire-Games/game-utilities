local sin = math.sin
local halfpi = math.pi / 2

return function(completed)
	return sin(completed * halfpi - halfpi) + 1
end