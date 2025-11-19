--https://github.com/jesusgollonet/ofpennereasing/blob/master/PennerEasing/Back.cpp

local s = 1.70158 --cool variable name penner

return function(completed)
	return completed ^ 2 * ((s + 1) * completed - s)
end