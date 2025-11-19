local easeOut = function(alpha, fun)
	return 1 - fun(1 - alpha)
end

return easeOut