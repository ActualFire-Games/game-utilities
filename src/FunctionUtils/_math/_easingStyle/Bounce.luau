--https://github.com/jesusgollonet/ofpennereasing/blob/master/PennerEasing/Bounce.cpp


local bounce = function(completed)
	if completed < 1 / 2.75 then
		return 7.5625 * completed ^ 2
	elseif completed < 2 / 2.75 then
		completed = completed - 1.5 / 2.75
		return 7.5625 * completed ^ 2 + 0.75
	elseif completed < 2.5 / 2.75 then
		completed = completed - 2.25 / 2.75
		return 7.5625 * completed ^ 2 + 0.9375
	else
		completed = completed - 2.625 / 2.75
		return 7.5625 * completed ^ 2 + 0.984375
	end
end

return function(completed)
	return 1 - bounce(completed) --For some reason, the mathematician behind these easing styles decided that easing should be inverted on this style. For another reason, Roblox agreed.
end