--https://github.com/jesusgollonet/ofpennereasing/blob/master/PennerEasing/Elastic.cpp

local sin = math.sin
local tau = math.pi * 2

return function(completed)
	return -(2 ^ (10 * (completed - 1)) * sin((completed - 1 - 3 / 40) * tau / .3))
end