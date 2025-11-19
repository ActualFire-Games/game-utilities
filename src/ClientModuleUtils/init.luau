--!strict
local _GuiButtonClass = require(script._GuiButtonClass)
export type WrappedGuiButton = _GuiButtonClass.WrappedGuiButton

local _GuiImageClass = require(script._GuiImageClass)
export type WrappedGuiImage = _GuiImageClass.WrappedGuiImage

local _GuiObjectClass = require(script._GuiObjectClass)
export type WrappedGuiObject = _GuiObjectClass.WrappedGuiObject

local _GuiStrokeClass = require(script._GuiStrokeClass)
export type WrappedGuiStroke = _GuiStrokeClass.WrappedUiStroke

local _GuiTextClass = require(script._GuiTextClass)
export type WrappedTextLabel = _GuiTextClass.WrappedTextLabel

local _SurfaceGuiClass = require(script._SurfaceGuiClass)
export type WrappedSurfaceGui = _SurfaceGuiClass.WrappedSurfaceGui

local _BillboardGuiClass = require(script._BillboardGuiClass)
export type WrappedBillboardGui = _BillboardGuiClass.WrappedBillboardGui

local _Input = require(script._Input)
export type GamepadType = _Input.GamepadType
export type MouseType = _Input.MouseType
export type KeyboardType = _Input.KeyboardType
export type TouchType = _Input.TouchType

return {
	GuiButtonClass = _GuiButtonClass,
	GuiImageClass = _GuiImageClass,
	GuiObjectClass = _GuiObjectClass,
	GuiStrokeClass = _GuiStrokeClass,
	GuiTextClass = _GuiTextClass,
	SurfaceGuiClass = _SurfaceGuiClass,
	BillboardGuiClass = _BillboardGuiClass,
    Input = _Input,
}