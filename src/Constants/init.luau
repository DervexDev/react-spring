--!optimize 2
--!strict

local Bezier = require(script.SimpleBezier)
local EasingFunctions = require(script.SimpleEasingFunctions)
local Types = require(script.Parent.Types)

local Constants = {}
Constants.Bezier = Bezier
Constants.EasingFunctions = EasingFunctions
Constants.Easings = EasingFunctions

Constants.Config = {
	default = {
		friction = 26,
		tension = 170,
	} :: Types.PartialSpringConfiguration,

	gentle = {
		friction = 14,
		tension = 120,
	} :: Types.PartialSpringConfiguration,

	wobbly = {
		friction = 12,
		tension = 180,
	} :: Types.PartialSpringConfiguration,

	stiff = {
		friction = 20,
		tension = 210,
	} :: Types.PartialSpringConfiguration,

	slow = {
		friction = 60,
		tension = 280,
	} :: Types.PartialSpringConfiguration,

	molasses = {
		friction = 120,
		tension = 280,
	} :: Types.PartialSpringConfiguration,

	snappy = {
		friction = 20,
		mass = 0.5,
		tension = 400,
	} :: Types.PartialSpringConfiguration,
}

export type EasingFunction = Types.EasingFunction

table.freeze(Constants.Config)
return table.freeze(Constants)
