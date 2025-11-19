--!strict
--[=[
	Utility functions that are related to the Spring object
	@class SpringUtils
    From Nevermore
]=]

local EPSILON = 1e-6

local LinearValue = require("../ModuleUtils/_LinearValue")
local Spring = require("../ModuleUtils/_Spring")
local t = require("./_t")

local SpringUtils = {}

--[=[
	Utility function that returns whether or not a spring is animating based upon
	velocity and closeness to target, and as the second value, the value that should be
	used.

	@param spring Spring<T>
	@param epsilon number? -- Optional epsilon
	@return boolean, T
]=]
@native
function SpringUtils.animating(spring: Spring.Spring<any>, epsilon: number?): (boolean, any)
	local epsilon = epsilon or EPSILON

	local position = spring.Position
	local target = spring.Target

	local animating
	if type(target) == "number" then
		animating = math.abs(spring.Position - spring.Target) > epsilon
			or math.abs(spring.Velocity) > epsilon
	else
		local rbxtype = typeof(target)
		if rbxtype == "Vector3" or rbxtype == "Vector2" or LinearValue.isLinear(target) then
			animating = (spring.Position - spring.Target).magnitude > epsilon
				or spring.Velocity.magnitude > epsilon
		else
			error("Unknown type")
		end
	end

	if animating then
		return true, position
	else
		-- We need to return the target so we use the actual target value (i.e. pretend like the spring is asleep)
		return false, target
	end
end

--[=[
	Add to spring position to adjust for velocity of target. May have to set clock to time().

	@param velocity T
	@param dampen number
	@param speed number
	@return T
]=]
@native
function SpringUtils.getVelocityAdjustment(velocity: any, dampen: number, speed: number): any
	assert(t.tuple(t.any, t.number, t.number)(velocity, dampen, speed))

	return velocity *( 2 * dampen / speed)
end

--[=[
	Converts an arbitrary value to a LinearValue if Roblox has not defined this value
	for multiplication and addition.

	@param value T
	@return LinearValue<T> | T
]=]
function SpringUtils.toLinearIfNeeded(value)
	return LinearValue.toLinearIfNeeded(value)
end

--[=[
	Extracts the base value out of a packed linear value if needed.

	@param value LinearValue<T> | any
	@return T | any
]=]
function SpringUtils.fromLinearIfNeeded(value)
	return LinearValue.fromLinearIfNeeded(value)
end

return SpringUtils