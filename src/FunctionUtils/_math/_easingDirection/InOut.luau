local easeIn = require(script.Parent.In)
local easeOut = require(script.Parent.Out)

local easeInOut = function(alpha, fun)
	if alpha < .5 then
		return easeIn(alpha * 2, fun) * .5
	else
		return .5 + easeOut(alpha * 2 - 1, fun) * .5
	end
end

return easeInOut