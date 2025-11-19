--!strict

-- PreferredInput
-- Stephen Leitnick
-- April 05, 2021 (updated 10/9/25 by @crusherfire)

export type InputType = "MouseKeyboard" | "Touch" | "Gamepad"

local UserInputService = game:GetService("UserInputService")

local touchUserInputType = Enum.UserInputType.Touch
local keyboardUserInputType = Enum.UserInputType.Keyboard

type PreferredInput = {
	Current: InputType,
	Observe: (handler: (inputType: InputType) -> (() -> ())?) -> () -> (),
}

local PreferredInput: PreferredInput

-- Track subscribers separately from their cleanup
local subscribers: { (inputType: InputType) -> (() -> ())? } = {}
local cleanupFunctionsPerSubscriber: { [(inputType: InputType) -> (() -> ())?]: () -> () } = {}

PreferredInput = {

	Current = "MouseKeyboard",

	Observe = function(handler: (inputType: InputType) -> (() -> ())?): () -> ()
		table.insert(subscribers, handler)

		-- Call handler immediately with error handling
		local success, cleanup = xpcall(function()
			local clean = handler(PreferredInput.Current)
			if clean ~= nil then
				assert(typeof(clean) == "function", "handler must return a function or nil")
			end
			return clean
		end, debug.traceback)

		-- If callback errored, print traceback
		if not success then
			local err = ""
			local firstLine = string.split(cleanup :: any, "\n")[1]
			local lastColon = string.find(firstLine, ": ")
			if lastColon then
				err = firstLine:sub(lastColon + 1)
			end
			warn(`error while calling PreferredInput.Observe() callback:{err}\n{cleanup}`)
		elseif cleanup then
			-- Store cleanup function
			cleanupFunctionsPerSubscriber[handler] = cleanup
		end

		-- Return disconnect function
		return function()
			local index = table.find(subscribers, handler)
			if index then
				-- Clean up before removing
				local cleanupFn = cleanupFunctionsPerSubscriber[handler]
				cleanupFunctionsPerSubscriber[handler] = nil
				if typeof(cleanupFn) == "function" then
					task.spawn(cleanupFn)
				end

				-- Remove from subscribers
				local n = #subscribers
				subscribers[index], subscribers[n] = subscribers[n], nil
			end
		end
	end,
}

local function SetPreferred(preferred: InputType)
	if preferred == PreferredInput.Current then
		return
	end
	PreferredInput.Current = preferred

	for _, subscriber in subscribers do
		task.spawn(function()
			-- Call cleanup from previous observation
			local oldCleanup = cleanupFunctionsPerSubscriber[subscriber]
			cleanupFunctionsPerSubscriber[subscriber] = nil
			if typeof(oldCleanup) == "function" then
				oldCleanup()
			end

			-- Call handler with new input type
			local success, cleanup = xpcall(function()
				local clean = subscriber(preferred)
				if clean ~= nil then
					assert(typeof(clean) == "function", "handler must return a function or nil")
				end
				return clean
			end, debug.traceback)

			-- If callback errored, print traceback
			if not success then
				local err = ""
				local firstLine = string.split(cleanup :: any, "\n")[1]
				local lastColon = string.find(firstLine, ": ")
				if lastColon then
					err = firstLine:sub(lastColon + 1)
				end
				warn(`error while calling PreferredInput.Observe() callback:{err}\n{cleanup}`)
			elseif cleanup then
				-- Store new cleanup function
				cleanupFunctionsPerSubscriber[subscriber] = cleanup
			end
		end)
	end
end

local function DeterminePreferred(inputType: Enum.UserInputType)
	if inputType == touchUserInputType then
		SetPreferred("Touch")
	elseif inputType == keyboardUserInputType or string.sub(inputType.Name, 1, 5) == "Mouse" then
		SetPreferred("MouseKeyboard")
	elseif string.sub(inputType.Name, 1, 7) == "Gamepad" then
		SetPreferred("Gamepad")
	end
end

DeterminePreferred(UserInputService:GetLastInputType())
UserInputService.LastInputTypeChanged:Connect(DeterminePreferred)

return PreferredInput