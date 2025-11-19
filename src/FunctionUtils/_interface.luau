--!strict
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Module = {}
local GuiService = game:GetService("GuiService")
local GamepadService = game:GetService("GamepadService")

local _input = require("./_input")
local Trove = require("../ModuleUtils/_Trove")
local Future = require("../ModuleUtils/_Future")
local observeProperty = require("./_observers/_observeProperty")

local camera = workspace.CurrentCamera

local function removeTags(str: string): string
	-- replace line break tags (otherwise grapheme loop will miss those linebreak characters)
	str = str:gsub("<br%s*/>", "\n")
	return (str:gsub("<[^<>]->", ""))
end

--[[
	Set to <code>nil</code> to exit gamepad selection.
	Updates <code>GuiService.SelectedObject</code>.
]]
function Module.setGamepadSelection(obj: GuiObject?)
	GuiService.SelectedObject = obj
end

--[[
	Returns <code>GuiService.SelectedObject</code>.
]]
function Module.getGamepadSelection(): GuiObject?
	return GuiService.SelectedObject
end

--[[
	Determines if gamepads can enter into UI selection mode or not.
	Updates <code>GuiService.AutoSelectGuiEnabled</code>.
]]
function Module.setAutoSelectGuiEnabled(enabled: boolean)
	GuiService.AutoSelectGuiEnabled = enabled
end

--[[
	Returns <code>GuiService.AutoSelectGuiEnabled</code>.
]]
function Module.getAutoSelectGuiEnabled()
	return GuiService.AutoSelectGuiEnabled
end

--[[
	Returns if the gamepad cursor is actively being used.
]]
function Module.isGamepadCursorEnabled()
	return GamepadService.GamepadCursorEnabled
end

--[[
	Exits the gamepad cursor.
]]
function Module.exitGamepadCursor()
	GamepadService:DisableGamepadCursor()
end

--[[
	Enters the gamepad cursor.
]]
function Module.enterGamepadCursor()
	GamepadService:EnableGamepadCursor()
end

--[[
	Grabs the left-hand canvas position of <code>object</code>.
	The parent must be a scrolling frame.
]]
function Module.getCanvasPosition(object: GuiObject): Vector2
	local scrollingFrame = object.Parent
	assert(typeof(scrollingFrame) == "Instance" and scrollingFrame:IsA("ScrollingFrame"), "invalid parent")
	return scrollingFrame.CanvasPosition + object.AbsolutePosition - scrollingFrame.AbsolutePosition
end

--[[
	Same as <code>getCanvasPosition()</code> but places the position at the center of the scrolling frame.
]]
function Module.getCentralCanvasPosition(object: GuiObject): Vector2
	local scrollingFrame = object.Parent
	assert(typeof(scrollingFrame) == "Instance" and scrollingFrame:IsA("ScrollingFrame"), "invalid parent")
	local objectCanvasPosition = scrollingFrame.CanvasPosition + object.AbsolutePosition - scrollingFrame.AbsolutePosition

	local scrollingFrameHalfSize = scrollingFrame.AbsoluteSize / 2
	local objectHalfSize = object.AbsoluteSize / 2

	return objectCanvasPosition - scrollingFrameHalfSize + objectHalfSize
end

-- Returns a boolean if the given <code>object</code> and all of its ancestors have <code>Visible</code> or <code>Enabled</code> set to true.
function Module.trulyVisible(object: GuiObject): boolean
	debug.profilebegin("Interface.trulyVisible")
	local parentGui = object:FindFirstAncestorWhichIsA("LayerCollector")

	if parentGui and parentGui.Enabled == false then
		return false
	end
	
	local currentCheck: Instance? = object.Parent
	while currentCheck ~= parentGui and currentCheck ~= nil do
		if currentCheck:IsA("GuiObject") and not currentCheck.Visible then
			return false
		end

		currentCheck = currentCheck.Parent
	end

	debug.profileend()
	return true
end

-- Client-side only!
-- <strong>includeInteractable</strong>: Should GuiObjects that have Interactable set to true be included?
-- WARNING: Setting <strong>includeInteractable</strong> to true will increase the time it takes to execute this function!
function Module.getGuiObjectsAtPosition(position: Vector2, includeInteractable: boolean?): { GuiObject }
	assert(RunService:IsClient(), "This function can only be called from the client!")
	debug.profilebegin("Interface.getGuiObjectsAtPosition()")
	local UserInputService = game:GetService("UserInputService")
	local player = game:GetService("Players").LocalPlayer

	local toggled = {}
	if includeInteractable then
		debug.profilebegin("set Interactable = false")
		for _, element in player.PlayerGui:GetDescendants() do
			if not element:IsA("GuiObject") then
				continue
			end
			if element.Interactable then
				element.Interactable = false
				table.insert(toggled, element)
			end
		end
		debug.profileend()
	end

	local result = player.PlayerGui:GetGuiObjectsAtPosition(position.X, position.Y)

	for _, element in toggled do
		element.Interactable = true
	end
	debug.profileend()
	return result
end

-- Client-side only!
function Module.isGuiObjectAtMousePosition(guiObject: GuiObject): boolean
	assert(RunService:IsClient(), "Only client can call this function!")
	debug.profilebegin("Interface.isGuiObjectAtMousePosition()")
	local UserInputService = game:GetService("UserInputService")
	local GuiService = game:GetService("GuiService")
	local player = game:GetService("Players").LocalPlayer
	local mouseLocation = UserInputService:GetMouseLocation()

	local updatedInteractable = false
	if guiObject.Interactable then
		guiObject.Interactable = false
		updatedInteractable = true
	end

	local offset: Vector2 = GuiService:GetGuiInset()
	local result = player.PlayerGui:GetGuiObjectsAtPosition(mouseLocation.X - offset.X, mouseLocation.Y - offset.Y)
	local found = false
	for _, obj in result do
		if obj == guiObject then
			found = true
			break
		end
	end

	if updatedInteractable then
		guiObject.Interactable = true
	end

	debug.profileend()
	return found
end

--[[
	Generates a <code>UDim2</code> position that is perpendicular to <code>pointA</code> and <code>pointB</code>.
	This assumes all positions are based from the entire screen size.
	<strong>alpha</strong>: Lerped position between pointA and pointB where offsetScale will be applied.
	<strong>offsetScale</strong>: Perpendicular offset multiplied against the pixel distance between pointA and pointB. (Negative values flip offset direction)
]]
function Module.getPerpendicularOffsetPosition(pointA: UDim2, pointB: UDim2, alpha: number, offsetScale: number, screenSize: Vector2): UDim2
	-- Due to pixel distances on scale being disproportionate, we must convert scale into pixels!
	local pointA = Vector2.new(
		pointA.X.Scale * screenSize.X + pointA.X.Offset,
		pointA.Y.Scale * screenSize.Y + pointA.Y.Offset
	)
	local pointB = Vector2.new(
		pointB.X.Scale * screenSize.X + pointB.X.Offset,
		pointB.Y.Scale * screenSize.Y + pointB.Y.Offset
	)

	local offsetOrigin = pointA:Lerp(pointB, alpha)

	local direction = pointB - pointA
	local perpendicular = Vector2.new(-direction.Y, direction.X).Unit

	local offsetPixels = perpendicular * (direction.Magnitude * offsetScale)

	local resultPixels = offsetOrigin + offsetPixels

	return UDim2.new(0, resultPixels.X, 0, resultPixels.Y), direction.Magnitude
end

--[[
	Returns the pixel unit direction between pointA and pointB and the original magnitude.
]]
function Module.getDirection(pointA: UDim2, pointB: UDim2, screenSize: Vector2): (Vector2, number)
	-- Due to pixel distances on scale being disproportionate, we must convert scale into pixels!
	local pointAPixels = Vector2.new(
		pointA.X.Scale * screenSize.X + pointA.X.Offset,
		pointA.Y.Scale * screenSize.Y + pointA.Y.Offset
	)
	local pointBPixels = Vector2.new(
		pointB.X.Scale * screenSize.X + pointB.X.Offset,
		pointB.Y.Scale * screenSize.Y + pointB.Y.Offset
	)
	local direction = (pointBPixels - pointAPixels)
	return direction.Unit, direction.Magnitude
end

--[[
	Generates a bezier curve Path2D that can be used for UI tweens.
	<strong>alpha</strong>: Lerped position between pointA and pointB where offsetScale will be applied.
	<strong>offsetScale</strong>: Perpendicular offset multiplied against the pixel distance between pointA and pointB. (Negative values flip offset direction)
	<strong>tangentScale</strong>: Tangent size multiplied against the pixel distance between pointA and pointB. 0.5 would be a tangent half the total distance.
]]
function Module.createCurvedPath2D(startPoint: UDim2, endPoint: UDim2, alpha: number, offsetScale: number, tangentScale: number): Path2D
	local screenSize = camera.ViewportSize
	local path = Instance.new("Path2D")
	local points: { Path2DControlPoint } = {}
	points[1] = Path2DControlPoint.new(startPoint)
	points[3] = Path2DControlPoint.new(endPoint)
	local midPointPosition = Module.getPerpendicularOffsetPosition(points[1].Position, points[3].Position, alpha, offsetScale, screenSize)
	points[2] = Path2DControlPoint.new(midPointPosition)
	
	local tangent, magnitude = Module.getDirection(startPoint, endPoint, screenSize)
	local tangentScale = (magnitude / 2) * tangentScale
	points[2].LeftTangent = UDim2.fromOffset(-tangent.X * tangentScale, -tangent.Y * tangentScale)
	points[2].RightTangent = UDim2.fromOffset(tangent.X * tangentScale, tangent.Y * tangentScale)
	path:SetControlPoints(points)
	path.Visible = false
	return path
end

-- Returns a corrected <code>UDim2</code> position for <code>uiElement</code> that matches the <code>screenPosition</code>.
-- This function accounts for the <code>AbsolutePosition</code> of uiElement's parent, enforces screen boundaries, and includes GUI inset if <code>IgnoreGuiInset</code> is disabled on the <code>gui</code>.
-- <strong>offset</strong>: Offset should be the difference between the <code>AbsolutePosition</code> of <code>uiElement</code> and <code>screenPosition</code> to stop snapping to the element's <code>AnchorPoint</code>.
function Module.getRelativePositionFromScreenPosition(screenPosition: Vector2, uiElement: GuiObject, gui: ScreenGui, offset: Vector2?): UDim2
	-- Retrieve screen size and GUI inset
	local offset = offset or Vector2.zero
	do
		-- Provided offset helps stop snapping to anchor point
		local absoluteSize = uiElement.AbsoluteSize
		local anchorPoint = uiElement.AnchorPoint
		local offsetX = absoluteSize.X * anchorPoint.X
		local offsetY = absoluteSize.Y * anchorPoint.Y
		local realOffset = offset + Vector2.new(offsetX, offsetY)
		screenPosition += realOffset
	end
	
	local parentFrame = uiElement.Parent :: GuiObject
	local viewportSize = camera.ViewportSize
	local guiInsetY = 0
	if not gui.IgnoreGuiInset then
		guiInsetY = game:GetService("GuiService"):GetGuiInset().Y
	end

	-- Calculate base position from the screen position
	local posX, posY = screenPosition.X, screenPosition.Y
	local parentAbsPos = parentFrame.AbsolutePosition
	local uiElementSize = uiElement.AbsoluteSize

	-- Offset to ensure position relative to parent frame
	local relativeX = posX - parentAbsPos.X
	local relativeY = posY - parentAbsPos.Y

	-- Calculate width and height offsets based on anchor point
	local widthOffset = uiElementSize.X * uiElement.AnchorPoint.X
	local heightOffset = uiElementSize.Y * uiElement.AnchorPoint.Y

	-- Adjust relative position to match the intended anchor point
	local adjustedX = relativeX
	local adjustedY = relativeY

	-- Boundaries check to keep UI within screen limits, accounting for anchor point
	local minX = 0 - parentAbsPos.X + widthOffset
	local minY = 0 - parentAbsPos.Y + heightOffset
	local maxX = viewportSize.X - parentAbsPos.X - (uiElementSize.X - widthOffset)
	local maxY = viewportSize.Y - parentAbsPos.Y - (uiElementSize.Y - heightOffset) - guiInsetY

	-- Clamp adjusted position to be within screen boundaries
	local finalX = math.clamp(adjustedX, minX, maxX)
	local finalY = math.clamp(adjustedY, minY, maxY)

	-- Return the calculated position as a UDim2 offset
	return UDim2.fromOffset(finalX, finalY)
end

function Module.getScreenSize()
	assert(camera, "Camera does not exist")

	return Vector2.new(camera.ViewportSize.X, camera.ViewportSize.Y)
end

function Module.offsetToScale(offset: Vector2, proportions: Vector2)
	assert(typeof(offset) == "Vector2", "offset is invalid or nil")
	assert(typeof(proportions) == "Vector2", "proportions is invalid or nil")

	local X, Y = offset.X, offset.Y
	X, Y = (X / proportions.X), (Y / proportions.Y)

	return Vector2.new(X, Y)
end

function Module.scaleToOffset(scale: Vector2, proportions: Vector2)
	assert(typeof(scale) == "Vector2", "scale is invalid or nil")
	assert(typeof(proportions) == "Vector2", "proportions is invalid or nil")

	local X, Y = scale.X, scale.Y
	X, Y = (X * proportions.X), (Y * proportions.Y)

	return Vector2.new(X, Y)
end

function Module.center(object: GuiObject)
	object.AnchorPoint = Vector2.new(0.5, 0.5)
	object.Position = UDim2.new(0.5, 0, 0.5, 0)
end

function Module.vec2UDim(vector2: Vector2, inScale: boolean)
	assert(typeof(vector2) == "Vector2", "vector2 is invalid or nil")

	return inScale and UDim2.fromScale(vector2.X, vector2.Y) or UDim2.fromOffset(vector2.X, vector2.Y)
end

-- Converts the UDim2 to scale based on the screen size.
-- <strong>screenSize</strong>: Overrides the screenSize
function Module.scaleUDim(udim: UDim2, screenSize: Vector2?)
	assert(typeof(udim) == "UDim2", "UDIm is invalid or nil")

	local offsetVector = Vector2.new(udim.X.Offset, udim.Y.Offset)
	local screenSize = screenSize or Module.getScreenSize()

	local resultVector = Module.offsetToScale(offsetVector, screenSize)

	return Module.vec2UDim(resultVector, true)
end

-- Converts the UDim2 to offset based on the screen size.
-- <strong>screenSize</strong>: Overrides the screenSize
function Module.offsetUDim(udim: UDim2, screenSize: Vector2?)
	assert(typeof(udim) == "UDim2", "UDIm is invalid or nil")

	local scaleVector = Vector2.new(udim.X.Scale, udim.Y.Scale)
	local screenSize = screenSize or Module.getScreenSize()

	local resultVector = Module.scaleToOffset(scaleVector, screenSize)

	return Module.vec2UDim(resultVector, false)
end

-- Client-side only!
-- Uses CoreGui to send a notification.
function Module.notify(title: string, text: string, duration: number, icon: string)
	assert(RunService:IsClient(), "notify() is client-only!")
	game:GetService("StarterGui"):SetCore("SendNotification",{
		Title = title or "No title specified",
		Text = text or "No text specified",
		Icon = icon,
		Duration = duration or 5,
	})
end

--[[
	Client-only!
	Fades in a black frame that hides the viewport.
	Returns a function that can be called to fade the frame back out & cleanup.
	If the cleanup is not given a TweenInfo, it instantly destroys the frame.
	<strong>displayOrder</strong>: Optionally define the rendering order for the Gui. Default is -1.
]]
function Module.fadeInBlack(tweenInfo: TweenInfo, displayOrder: number?): (Tween, (tweenInfo: TweenInfo?) -> (Tween?)) 
	assert(RunService:IsClient(), "fadeInBlack() is client-only!")
	local gui = Instance.new("ScreenGui")
	gui.Name = "__FADE_GUI__"
	gui.DisplayOrder = displayOrder or -1
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true

	local blackFrame = Instance.new("Frame")
	blackFrame.Size = UDim2.fromScale(1, 1)
	blackFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	blackFrame.Transparency = 1
	blackFrame.Parent = gui

	gui.Parent = Players.LocalPlayer.PlayerGui
	gui = gui
	
	local tween = TweenService:Create(blackFrame, tweenInfo, { Transparency = 0 })
	tween:Play()
	
	return tween, function(tweenInfo: TweenInfo?)
		local tween
		if tweenInfo then
			tween = TweenService:Create(blackFrame, tweenInfo, { Transparency = 1 })
			tween.Completed:Once(function()
				gui:Destroy()
			end)
			tween:Play()
		else
			gui:Destroy()
		end
		return tween
	end
end

-- Applies a black, semi-transparent frame to the obj to make it look disabled.
function Module.applyDisabledOverlay(obj: GuiObject): Frame
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.new()
	frame.BackgroundTransparency = 0.5
	frame.Size = UDim2.fromScale(1, 1)
	frame.Name = "_disabledOverlay"
	frame.Parent = obj
	return frame
end

-- Looks for the frame created by applyDisabledOverlay() and destroys it.
function Module.clearDisabledOverlay(obj: GuiObject)
	local frame = obj:FindFirstChild("_disabledOverlay")
	if frame then
		frame:Destroy()
	end
end

local defaultTime = 0.25
@deprecated
function Module.typeAnimation(textLabel: TextLabel, text: string?, timeBtwLetters: number?, yield: boolean?)
	assert(typeof(textLabel) == "Instance" and textLabel:IsA("TextLabel"), "Missing TextLabel")
	
	if not timeBtwLetters then
		timeBtwLetters = defaultTime
	end
	
	yield = if yield == nil then true else yield
	textLabel.MaxVisibleGraphemes = 0
	textLabel.Text = text or textLabel.Text
	
	if yield then
		for i = 0, string.len(textLabel.Text), 1 do
			textLabel.MaxVisibleGraphemes = i
			task.wait(timeBtwLetters)
		end
	else
		task.spawn(function()
			for i = 0, string.len(textLabel.Text), 1 do
				textLabel.MaxVisibleGraphemes = i
				task.wait(timeBtwLetters)
			end
		end)
	end
end

function Module.animateText(textLabel: TextLabel, onNewGrapheme: ( (TextLabel) -> () )?, text: string?, interval: number?): Future.Future<>
	text = text or textLabel.Text
	interval = interval or 0.025
	
	textLabel.RichText = true
	textLabel.Text = text :: string
	textLabel.MaxVisibleGraphemes = 0

	-- count graphemes (approximated by utf8 codepoints)
	local total = 0
	for _ in utf8.graphemes(removeTags(text :: string)) do
		total += 1
	end
	
	return Future.new(function()
		for i = 1, total do
			textLabel.MaxVisibleGraphemes = i
			if onNewGrapheme then
				task.spawn(onNewGrapheme, textLabel)
			end
			task.wait(interval)
		end
	end)
end

--[[
	Creates a outline
]]
function Module.outlineGuiObject(guiObject: GuiObject, highlightTweenInfo: TweenInfo?, strokeProperties: {[string]: any}?): Frame
	local highLightFrame = Instance.new("Frame")
	highLightFrame.Parent = guiObject
	highLightFrame.Size = UDim2.fromScale(1,1)
	highLightFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	highLightFrame.Position = UDim2.fromScale(0.5, 0.5)
	highLightFrame.BackgroundTransparency = 1
	local uiStroke = Instance.new("UIStroke") :: any
	uiStroke.Parent = highLightFrame
	uiStroke.Thickness = 5
	uiStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	uiStroke.LineJoinMode = Enum.LineJoinMode.Round
	uiStroke.Color = Color3.new(0.0666667, 1, 0.486275)
	
	if strokeProperties then
		for property, value in pairs(strokeProperties) do
			if not uiStroke[property] then
				continue
			end
			uiStroke[property] = value
		end
	end
	
	highlightTweenInfo = highlightTweenInfo or TweenInfo.new(.3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, true)
	
	local tween = TweenService:Create(highLightFrame, highlightTweenInfo, {Size = UDim2.new(1, 10, 1, 10)})
	tween:Play()

	highLightFrame.ZIndex = guiObject.ZIndex + 1
	return highLightFrame
end

--[[
	Focuses the <code>guiObject</code> by using a <code>UIStroke</code> and obscuring other UI elements.
	This can only be performed on UI elements within a <code>ScreenGui</code>.
	Returns a cleanup function that can optionally fade out the focus and a tween (if <code>tweenInfo</code> is provided).
	<strong>tweenInfo</strong>: Provide a TweenInfo to fade in the focus.
	<strong>displayOrder</strong>: Optionally set for the gui containing the stroke. Default is 100.
	<strong>color</strong>: Default color is black.
	<strong>transparency</strong>: Default is 0.25.
]]
function Module.focusGuiObject(guiObject: GuiObject, tweenInfo: TweenInfo?, displayOrder: number?, color: Color3?, transparency: number?): ( (tweenInfo: TweenInfo?) -> ( Tween? ), Tween? )
	assert(guiObject:FindFirstAncestorWhichIsA("ScreenGui"), "guiObject must be a descendant of a ScreenGui")
	local trove = Trove.new()
	local stroke = Instance.new("UIStroke")
	stroke.Name = "FocusStroke"
	stroke.Transparency = 1
	stroke.Color = color or Color3.new(0, 0, 0)
	stroke.Thickness = 20_000
	trove:Add(stroke)
	
	local gui = Instance.new("ScreenGui")
	gui.Name = "_FocusStrokeGui"
	gui.DisplayOrder = displayOrder or 100
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	trove:Add(gui)
	
	local guiObjectZone = Instance.new("Frame")
	guiObjectZone.Transparency = 1
	trove:Add(observeProperty(guiObject, "AbsolutePosition", function(absolutePosition: Vector2)
		guiObjectZone.Position = UDim2.fromOffset(absolutePosition.X, absolutePosition.Y)
		return
	end))
	trove:Add(observeProperty(guiObject, "AbsoluteSize", function(absoluteSize: Vector2)
		guiObjectZone.Size = UDim2.fromOffset(absoluteSize.X, absoluteSize.Y)
		return
	end))
	trove:Add(guiObjectZone)
	
	local tween
	if tweenInfo then
		tween = TweenService:Create(stroke, tweenInfo, { Transparency = transparency or 0.25 })
		tween:Play()
	else
		stroke.Transparency = transparency or 0.25
	end

	stroke.Parent = guiObjectZone
	guiObjectZone.Parent = gui
	gui.Parent = Players.LocalPlayer.PlayerGui

	return function(tweenInfo: TweenInfo?)
		local tween
		if tweenInfo then
			tween = TweenService:Create(stroke, tweenInfo, { Transparency = 1 })
			tween:Play()
			tween.Completed:Once(function()
				trove:Clean()
			end)
		else
			trove:Clean()
		end
		return tween
	end, tween
end

-- Grabs a string that represents the keycode with some shortened strings for specific strings.
-- This is an artistic preference.
@[deprecated {use="Input.getStringForKeyCode"}]
function Module.getStringForKeyCode(keycode: Enum.KeyCode): string
	return _input.getStringForKeyCode(keycode)
end

-- Returns a string image id for the keycode.
@[deprecated {use="Input.getImageForKeyCode"}]
function Module.getImageForKeyCode(keycode: Enum.KeyCode): string
	return _input.getImageForKeyCode(keycode)
end

return Module
